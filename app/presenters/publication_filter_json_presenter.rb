class PublicationFilterJsonPresenter < DocumentFilterPresenter
  def as_json(options = nil)
    super.merge atom_feed_url: context.filter_atom_feed_url
  end

  def result_type
    "publication"
  end
end
