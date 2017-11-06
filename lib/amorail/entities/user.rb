require 'amorail/entities/leadable'

module Amorail
  class User < Amorail::Entity
    include Leadable

    amo_names 'users'

    amo_field :name, :login, :last_name, :id

    validates :name, presence: true

    def self.remote_url(name = '')
      '/private/api/v2/json/accounts/current/users'
    end

    def body_response(response)
      response.body['response']['account']
    end

    def params
      data = super
      data[:type] = 'user'
      data
    end
  end
end
