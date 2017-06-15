module ObservationReport
  # Format for export to Mycoflora.
  class Mycoflora < ObservationReport::CSV
    def labels
      %w(
        moId
        scientificName
        scientificNameAuthorship
        taxonRank
        collectorsName
        collectionDate
        collectionLocation
        decimalLatitude
        decimalLongitude
        elevationInMeters
        minimumDecimalLatitude
        maximumDecimalLatitude
        minimumDecimalLongitude
        maximumDecimalLongitude
        minimumElevationInMeters
        maximumElevationInMeters
        updatedAt
        fieldNotes
        moUrl
        imageUrls
      )
    end

    def format_row(row)
      [
        row.obs_id,
        row.name_text_name,
        row.name_author,
        row.name_rank,
        row.user_name_or_login,
        row.obs_when,
        row.loc_name_sci,
        row.obs_lat(4),
        row.obs_long(4),
        row.obs_alt,
        row.loc_south,
        row.loc_north,
        row.loc_west,
        row.loc_east,
        row.loc_low,
        row.loc_high,
        row.obs_updated_at,
        row.obs_notes,
        row.obs_url,
        image_urls(row)
      ]
    end

    def image_urls(row)
      row.val(1).to_s.split(", ").sort_by(&:to_i).
        map { |id| "#{MO.http_domain}/#{Image.url(:full_size, id)}" }.
        join(" ")
    end

    def extend_data!(rows)
      add_image_ids!(rows, 1)
    end

    def sort_after(rows)
      rows.sort_by { |row| row[0].to_i }
    end
  end
end
