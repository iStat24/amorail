require 'active_support/core_ext/hash/indifferent_access'

module Amorail # :nodoc: all
  class Entity
    def params
      data = {}
      self.class.attributes.each do |k, v|
        data[k] = send("to_#{v}", send(k))
      end
      if properties.respond_to?(amo_name)
        data[:custom_fields] = client.try(:custom_options).try(:any?) ? custom_options(client.custom_options) : custom_fields
      end
      normalize_params(data)
    end

    protected

    def custom_fields
      props = properties.send(self.class.amo_name)

      custom_fields = []

      self.class.properties.each do |k, v|
        prop_id = props.send(k).id
        prop_val = { value: send(k) }.merge(v)
        custom_fields << { id: prop_id, values: [prop_val] }
      end

      custom_fields
    end

    def custom_options(options)
      custom_options = []

      options.each do |k, v|
        if v.is_a? Array
          custom_options << { id: k, values: v }
        else
          custom_options << { id: k, values: [{value: v}] }
        end
      end
      custom_options
    end

    def create_params(method)
      result = {
        request: {
          self.class.amo_response_name => {
            method => [
              params
            ]
          }
        }
      }
      result[:request][self.class.amo_response_name][:category] = self.category.to_s if self.is_a?(Unsorted)
      result
    end

    def normalize_custom_fields(val)
      val.reject do |field|
        field[:values].all? { |item| !item[:value] }
      end
    end

    # this method removes nil values and empty arrays from params hash (deep)
    # rubocop:disable Metrics/CyclomaticComplexity
    # rubocop:disable Metrics/MethodLength
    def normalize_params(data)
      return data unless data.is_a?(Hash)

      compacted = {}
      data.each do |key, val|
        case val
        when Numeric, String
          compacted[key] = val
        when Array
          val.compact!
          # handle custom keys
          val = normalize_custom_fields(val) if key == :custom_fields
          unless val.empty?
            compacted[key] = val.map { |el| normalize_params(el) }
          end
        else
          params = normalize_params(val)
          compacted[key] = params unless params.nil?
        end
      end
      compacted.with_indifferent_access
    end
    # rubocop:enable Metrics/CyclomaticComplexity
    # rubocop:enable Metrics/MethodLength

    def to_timestamp(val)
      return if val.nil?

      case val
      when String
        (date = Time.parse(val)) && date.to_i
      when Date
        val.to_time.to_i
      else
        val.to_i
      end
    end

    def to_default(val)
      val
    end
  end
end
