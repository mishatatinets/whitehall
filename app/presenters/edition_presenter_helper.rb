module EditionPresenterHelper
  def as_hash
    {
      id: model.id,
      type: model.type.underscore,
      display_type: model.display_type,
      title: model.title,
      url: link,
      organisations: display_organisations.html_safe,
      display_date_microformat: display_date_microformat,
      public_timestamp: model.public_timestamp
    }
  end

  def link
    if model.responds_to?(:link)
      model.link
    else #non rummager response
      context.link_to model.title, context.public_document_path(model)
    end
  end

  def display_organisations
    organisations.map { |o|
      context.organisation_display_name(o)
    }.to_sentence
  end

  def display_date_microformat
    date_microformat(:public_timestamp)
  end

  def date_microformat(attribute_name)
    context.render_datetime_microformat(model, attribute_name) {
      context.l(model.send(attribute_name).to_date, format: :long_ordinal)
    }
  end
end
