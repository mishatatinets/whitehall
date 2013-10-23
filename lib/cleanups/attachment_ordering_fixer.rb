class AttachmentOrderingFixer

  attr_reader :logger

  class OldAttachment < Attachment; end
  OldAttachment.table_name = :old_attachments

  def initialize(options = {})
    @logger = options[:logger] || Logger.new(nil)
  end

  def self.run!(options = {})
    AttachmentOrderingFixer.new(options).run!
  end

  def run!
    Document.find_each do |doc|
      unless doc.latest_edition.try(:allows_attachments?)
        logger.info "Skipping #{doc.id} because it does not allow attachments"
        next
      end
      if manually_ordered_edition = manually_ordered?(doc)
        logger.info "Skipping #{doc.id} because #{manually_ordered_edition.id} was manually ordered"
        next
      end

      fix(doc)
    end
  end

  def fix(doc)
    last_known_good_edition = nil
    doc.editions.order(:id).each do |edition|
      if created_before_polymorphic_attachments_code_deployed?(edition)
        logger.info "#{edition.class}##{edition.id} - created before #{polymorphic_attachments_code_deployed_at}, using attachment IDs"
        fix_ordering_using_attachment_ids(edition)
        last_known_good_edition = edition
      elsif was_first_edition_after_polymorphic_attachments_code_deployed?(doc, edition) && created_before_timestamp_ordering_fix?(edition)
        logger.info "#{edition.class}##{edition.id} - first edition after #{polymorphic_attachments_code_deployed_at}, using attachment IDs"
        fix_ordering_using_attachment_ids(edition)
        last_known_good_edition = edition
      elsif last_known_good_edition.nil?
        logger.info "Skipping #{edition.class}##{edition.id} because no last known good edition - CHECK INTEGRITY - Major: #{edition.published_major_version} Minor: #{edition.published_minor_version}"
      else
        logger.info "#{edition.class}##{edition.id} - 2+ editions after #{polymorphic_attachments_code_deployed_at}, fixing with last known good edition"
        fix_ordering_using_last_known_good_edition(last_known_good_edition, edition)
      end
    end
  end

  def manually_ordered?(doc)
    doc.editions.where('created_at < ?', polymorphic_attachments_code_deployed_at).find do |edition|
      old_attachments = OldAttachment.where(id: edition.attachment_ids)

      old_attachments.order(:ordering).map(&:ordering) == (0...old_attachments.length).to_a
    end
  end

  def created_before_polymorphic_attachments_code_deployed?(edition)
    edition.created_at < polymorphic_attachments_code_deployed_at
  end

  def polymorphic_attachments_code_deployed_at
    Time.zone.parse("2013-10-07 10:14:05 UTC")
  end

  def created_before_timestamp_ordering_fix?(edition)
    edition.created_at < timestamp_fix_ran_at
  end

  def timestamp_fix_ran_at
    Time.zone.parse("2013-10-11 12:59:31 UTC")
  end

  def was_first_edition_after_polymorphic_attachments_code_deployed?(doc, edition)
    first_edition_after_polymorphic_attachments_code_deployed(doc) == edition
  end

  def first_edition_after_polymorphic_attachments_code_deployed(doc)
    doc.editions.order(:id).find {|e| e.created_at > polymorphic_attachments_code_deployed_at }
  end

  def fix_ordering_using_attachment_ids(edition)
    resorted_attachments = edition.attachments.sort_by(&:id)
    nil_attachments, old_attachments = OldAttachment.where(id: edition.attachment_ids).partition(&:nil?)

    resorted_attachments.each_with_index do |attachment, index|
      old_attachment = old_attachments.detect { |o| o.id == attachment.id }
      logger.info "-- #{attachment.id} #{old_attachment.try(:ordering)}->#{attachment.ordering}->#{index}"
      attachment.update_column(:ordering, index)
    end
  end

  def fix_ordering_using_last_known_good_edition(last_known_good_edition, edition)
    old_attachments_by_attachment_data_id = last_known_good_edition.attachments.includes(:attachment_data).each_with_object({}) do |a, hash|
      hash[a.attachment_data_id] = a
      hash[a.attachment_data.replaced_by_id] = a if a.attachment_data.replaced_by_id
    end

    new_attachments_to_put_at_the_end = []
    highest_seen_ordering = nil
    edition.attachments.each do |attachment|
      matching_attachment_from_previous_edition = old_attachments_by_attachment_data_id[attachment.attachment_data_id]

      if matching_attachment_from_previous_edition
        logger.info "-- #{attachment.id} #{matching_attachment_from_previous_edition.ordering}->#{attachment.ordering}->#{matching_attachment_from_previous_edition.ordering}"
        attachment.update_column(:ordering, matching_attachment_from_previous_edition.ordering)
        highest_seen_ordering ||= matching_attachment_from_previous_edition.ordering
        highest_seen_ordering = [highest_seen_ordering, matching_attachment_from_previous_edition.ordering].max
      else
        new_attachments_to_put_at_the_end << attachment
      end
    end

    highest_seen_ordering ||= 0
    new_attachments_to_put_at_the_end.each.with_index do |attachment, i|
      new_ordering = highest_seen_ordering + i + 1
      logger.info "-- #{attachment.id} NEW->#{attachment.ordering}->#{new_ordering}"
      attachment.update_column(:ordering, new_ordering)
    end
  end
end
