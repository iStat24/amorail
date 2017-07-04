require 'faraday'
require 'faraday_middleware'
require 'json'
require 'active_support'

module Amorail
  # Amorail http client
  class Client
    attr_reader :usermail, :api_key, :api_endpoint, :custom_options

    def initialize(api_endpoint: Amorail.config.api_endpoint,
                   api_key: Amorail.config.api_key,
                   usermail: Amorail.config.usermail,
                   custom_options: {})
      @api_endpoint = api_endpoint
      @api_key = api_key
      @usermail = usermail
      @custom_options = custom_options if custom_options.any?
      @connect = Faraday.new(url: api_endpoint) do |faraday|
        faraday.adapter Faraday.default_adapter
        faraday.response :json, content_type: /\bjson$/
        faraday.use :instrumentation
      end
    end
    def properties
      @properties ||= Property.new(self)
    end

    def connect
      @connect || self.class.new
    end

    def authorize
      self.cookies = nil
      response = post(
        Amorail.config.auth_url,
        'USER_LOGIN' => usermail,
        'USER_HASH' => api_key
      )
      cookie_handler(response)
      response
    end

    def safe_request(method, url, params = {})
      send(method, url, params)
    rescue ::Amorail::AmoUnauthorizedError
      authorize
      send(method, url, params)
    end

    def get(url, params_in = {})
      headers = params_in[:headers]
      params  = params_in.clone
      params.delete(:headers)      
      response = connect.get(url, params) do |request|
        request.headers['Cookie'] = cookies if cookies.present?
        headers&.each { |k, v| request.headers[k.to_s] = v.to_s }
      end
      handle_response(response)
    end

    def post(url, params_in = {})
      headers = params_in[:headers]
      params  = params_in.clone
      params.delete(:headers)
      response = connect.post(url) do |request|
        request.headers['Cookie'] = cookies if cookies.present?
        request.headers['Content-Type'] = 'application/json'
        headers&.each { |k, v| request.headers[k.to_s] = v.to_s }
        request.body = params.to_json
      end
      handle_response(response)
    end

    private

    attr_accessor :cookies

    def cookie_handler(response)
      self.cookies = response.headers['set-cookie'].split('; ')[0]
    end

    def handle_response(response) # rubocop:disable all
      return response if [200, 201, 204].include? response.status
      case response.status
      when 301
        fail ::Amorail::AmoMovedPermanentlyError
      when 400
        fail ::Amorail::AmoBadRequestError
      when 401
        fail ::Amorail::AmoUnauthorizedError
      when 403
        fail ::Amorail::AmoForbiddenError
      when 404
        fail ::Amorail::AmoNotFoundError
      when 500
        fail ::Amorail::AmoInternalError
      when 502
        fail ::Amorail::AmoBadGatewayError
      when 503
        fail ::Amorail::AmoServiceUnaviableError
      else
        fail ::Amorail::AmoUnknownError(response.body)
      end
    end
  end
end
