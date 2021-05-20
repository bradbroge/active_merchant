module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class PayTraceGateway < Gateway
      self.test_url = 'https://api.paytrace.com'
      self.live_url = 'https://api.paytrace.com'

      self.supported_countries = ['US']
      self.default_currency = 'USD'
      self.supported_cardtypes = %i[visa master american_express discover]

      self.homepage_url = 'https://paytrace.com/'
      self.display_name = 'PayTrace'

      STANDARD_ERROR_CODE_MAPPING = {
        '1'   => STANDARD_ERROR_CODE[:card_declined],
        '102' => STANDARD_ERROR_CODE[:declined],
        '400' => STANDARD_ERROR_CODE[:processing_error],
        '401' => STANDARD_ERROR_CODE[:processing_error],
        '500' => STANDARD_ERROR_CODE[:processing_error]
      }

      def initialize(options = {})
        requires!(options, :username, :password, :access_token)
        super
        acquire_access_token
      end

      def purchase(money, payment, options = {})
        post = {}
        add_invoice(post, money, options)
        add_payment(post, payment)
        add_address(post, payment, options)
        add_customer_data(post, options)

        response = commit('sale/keyed', post)
        check_token_response(response, 'sale/keyed', post, options)
      end

      def authorize(money, payment, options = {})
        post = {}
        add_invoice(post, money, options)
        add_payment(post, payment)
        add_address(post, payment, options)
        add_customer_data(post, options)

        response = commit('authorization/keyed', post)
        check_token_response(response, 'authorization/keyed', post, options)
      end

      def capture(money, authorization, options = {})
        # needs transaction id and integrator id only
        post = {}
        post[:transaction_id] = authorization
        post[:integrator_id] = @options[:integrator_id]
        response = commit('authorization/capture', post)
        check_token_response(response, 'authorization/capture', post, options)
      end

      def refund(money, authorization, options = {})
        # we will only support full and partial refunds of settled transactions via a transaction ID
        post = {}
        post[:transaction_id] = authorization
        post[:integrator_id] = @options[:integrator_id]

        response = commit('refund/for_transaction', post)
        check_token_response(response, 'refund/for_transaction', post, options)
      end

      def void(authorization, options = {})
        post = {}
        post[:transaction_id] = authorization
        post[:integrator_id] = @options[:integrator_id]
        commit('void', post)
      end

      def verify(credit_card, options = {})
        MultiResponse.run(:use_first_response) do |r|
          r.process { authorize(100, credit_card, options) }
          r.process(:ignore_result) { void(r.authorization, options) }
        end
      end

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        transcript
      end

      def check_token_response(response, endpoint, body = {}, options = {})
        return response unless response.params['error'] == 'invalid_token'

        acquire_access_token
        commit(endpoint, body)
      end

      def acquire_access_token
        post = {}
        post[:grant_type] = 'password'
        post[:username] = @options[:username]
        post[:password] = @options[:password]
        data = post.collect { |key, value| "#{key}=#{CGI.escape(value.to_s)}" }.join('&')
        url = live_url + '/oauth/token'
        oauth_headers = {
          'Accept'            => '*/*',
          'Content-Type'      => 'application/x-www-form-urlencoded'
        }
        response = ssl_post(url, data, oauth_headers)
        json_response = JSON.parse(response)

        @options[:access_token] = json_response['access_token'] if json_response['access_token']
        response
      end

      private

      def add_customer_data(post, options); end

      def add_address(post, creditcard, options)
        return unless options[:billing_address] || options[:address]

        address = options[:billing_address] || options[:address]
        post[:billing_address] = {}
        post[:billing_address][:name] = creditcard.name
        post[:billing_address][:street_address] = address[:address1]
        post[:billing_address][:city] = address[:city]
        post[:billing_address][:state] = address[:state]
        post[:billing_address][:zip] = address[:zip]
      end

      def add_invoice(post, money, options)
        post[:amount] = amount(money)
        # post[:currency] = (options[:currency] || currency(money))
      end

      def add_payment(post, payment)
        post[:credit_card] = {}
        post[:credit_card][:number] = payment.number
        post[:credit_card][:expiration_month] = payment.month
        post[:credit_card][:expiration_year] = payment.year
      end

      def parse(body)
        JSON.parse(body)
      end

      def commit(action, parameters)
        base_url = (test? ? test_url : live_url)
        url = base_url + '/v1/transactions/' + action
        response = parse(ssl_post(url, post_data(parameters), headers))

        Response.new(
          success_from(response),
          message_from(response),
          response,
          authorization: authorization_from(response),
          avs_result: AVSResult.new(code: response['avs_response']),
          cvv_result: CVVResult.new(response['csc_response']),
          test: test?,
          error_code: error_code_from(response)
        )
      end

      def headers
        {
          'Content-type' => 'application/json',
          'Authorization' => 'Bearer ' + @options[:access_token]
        }
      end

      def success_from(response)
        response['success']
      end

      def message_from(response)
        response['status_message']
      end

      def authorization_from(response)
        response['transaction_id']
      end

      def post_data(parameters = {})
        parameters[:password] = @options[:password]
        parameters[:username] = @options[:username]
        parameters[:integrator_id] = @options[:integrator_id]

        parameters.to_json
      end

      def error_code_from(response)
        response['response_code']
      end

      # this method is not currently working as needed
      # def handle_response(response)
      #   case response.code.to_i
      #   when 200...300
      #     response
      #   else
      #     raise ResponseError.new(response)
      #   end
      # end
    end
  end
end
