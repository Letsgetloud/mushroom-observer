xml.tag!(tag,
  id: object.id,
  url: object.show_url,
  type: "name"
) do
  xml_string(xml, :name, object.real_text_name)
  xml_string(xml, :author, object.author)
  xml_string(xml, :rank, object.rank.to_s.downcase)
  xml_boolean(xml, :deprecated, true) if object.deprecated
  xml_boolean(xml, :misspelled, true) if object.is_misspelling?
  xml_html_string(xml, :citation, object.citation.to_s.tl)
  xml_html_string(xml, :notes, object.notes.to_s.tpl_nodiv)
  xml_datetime(xml, :created_at, object.created_at)
  xml_datetime(xml, :updated_at, object.updated_at)
  xml_integer(xml, :number_of_views, object.num_views)
  xml_datetime(xml, :last_viewed, object.last_view)
  xml_boolean(xml, :ok_for_export, true) if object.ok_for_export
  if !detail
    if object.synonym_id
      xml_minimal_object_old(xml, :synonym, Synonym, object.synonym_id)
    end
  else
    if object.synonym
      xml.synonyms(number: object.synonym.names.length - 1) do
        for synonym in object.synonym.names - [object]
          xml_detailed_object_old(xml, :synonym, synonym)
        end
      end
    end
    unless object.classification.blank?
      parse = Name.parse_classification(object.classification)
      xml.parents(number: parse.length) do
        for rank, name in parse
          xml.parent do
            xml_string(xml, :name, name)
            xml_string(xml, :rank, rank.to_s.downcase)
          end
        end
      end
    end
  end
end
