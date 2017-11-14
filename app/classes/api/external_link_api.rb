class API
  # API for ExternalLink
  class ExternalLinkAPI < ModelAPI
    self.model = ExternalLink

    self.high_detail_page_length = 100
    self.low_detail_page_length  = 1000
    self.put_page_length         = 1000
    self.delete_page_length      = 1000

    self.high_detail_includes = [
      :external_site,
      :object,
      :user
    ]

    def query_params
      {
        where:          sql_id_condition,
        created_at:     parse_range(:time, :created_at),
        updated_at:     parse_range(:time, :updated_at),
        users:          parse_array(:user, :user),
        observations:   parse_array(:observation, :observations),
        external_sites: parse_array(:external_site, :external_sites),
        url:            parse(:string, :url)
      }
    end

    def create_params
      {
        user:          @user,
        observation:   parse(:observation, :observation),
        external_site: parse(:external_site, :external_site),
        url:           parse(:string, :url)
      }
    end

    def validate_create_params!(params)
      raise MissingParameter.new(:observation)   unless params[:observation]
      raise MissingParameter.new(:external_site) unless params[:external_site]
      raise MissingParameter.new(:url)           if params[:url].blank?
      # TODO: check permissions
    end

    def update_params
      {
        url: parse(:string, :set_url)
      }
    end
  end
end
