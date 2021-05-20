require 'test_helper'

class PayTraceTest < Test::Unit::TestCase
  def setup
    @gateway = PayTraceGateway.new(fixtures(:pay_trace))
    @credit_card = credit_card('4012000098765439')
    @mastercard = credit_card('5499740000000057')
    @declined_card = credit_card('4012000098760000')
    @amount = 100

    @options = {
      order_id: '1',
      billing_address: address,
      description: 'Store Purchase'
    }
  end

  # def test_response_handler_success
  #   response = Struct.new(:code).new(200)
  #   assert_equal response, @gateway.send(:handle_response, response)
  # end

  # def test_response_handler_failure
  #   response = Struct.new(:code).new(400)
  #   assert_raise ActiveMerchant::ResponseError do
  #     @gateway.send(:handle_response, response)
  #   end
  # end

  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response

    assert_equal 392483066, response.authorization
    assert response.test?
  end

  # def test_failed_purchase
  #   @gateway.expects(:ssl_post).returns(failed_purchase_response)

  #   response = @gateway.purchase(@amount, @mastercard, @options)
  #   assert_failure response
  #   assert_equal Gateway::STANDARD_ERROR_CODE[:card_declined], response.error_code
  # end

  def test_successful_authorize
    @gateway.expects(:ssl_post).returns(successful_authorize_response)

    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response
    assert_equal true, response.success
  end

  def test_failed_authorize; end

  def test_successful_capture; end

  def test_failed_capture; end

  def test_successful_refund; end

  def test_failed_refund; end

  def test_successful_void; end

  def test_failed_void; end

  def test_successful_verify; end

  def test_successful_verify_with_failed_void; end

  def test_failed_verify; end

  def test_scrub
    assert @gateway.supports_scrubbing?
    assert_equal @gateway.scrub(pre_scrubbed), post_scrubbed
  end

  private

  def pre_scrubbed
    '
      Run the remote tests for this gateway, and then put the contents of transcript.log here.
    '
  end

  def post_scrubbed
    '
      Put the scrubbed contents of transcript.log here after implementing your scrubbing function.
      Things to scrub:
        - Credit card number
        - CVV
        - Sensitive authentication details
    '
  end

  def successful_purchase_response
    "{\"success\":true,\"response_code\":101,\"status_message\":\"Your transaction was successfully approved.\",\"transaction_id\":392483066,\"approval_code\":\"TAS610\",\"approval_message\":\"  NO  MATCH - Approved and completed\",\"avs_response\":\"No Match\",\"csc_response\":\"\",\"external_transaction_id\":\"\",\"masked_card_number\":\"xxxxxxxxxxxx5439\"}"
  end

  def failed_purchase_response
    "{\"success\":false,\"response_code\":102,\"status_message\":\"Your transaction was not approved.\",\"transaction_id\":392501201,\"approval_code\":\"\",\"approval_message\":\"    DECLINE - Do not honor\",\"avs_response\":\"No Match\",\"csc_response\":\"\",\"external_transaction_id\":\"\",\"masked_card_number\":\"xxxxxxxxxxxx5439\"}"
  end

  def successful_authorize_response
    "{\"success\":true,\"response_code\":101,\"status_message\":\"Your transaction was successfully approved.\",\"transaction_id\":392224547,\"approval_code\":\"TAS161\",\"approval_message\":\"  NO  MATCH - Approved and completed\",\"avs_response\":\"No Match\",\"csc_response\":\"\",\"external_transaction_id\":\"\",\"masked_card_number\":\"xxxxxxxxxxxx2224\"}"
  end

  def failed_authorize_response; end

  def successful_capture_response
    "{\"success\":true,\"response_code\":112,\"status_message\":\"Your transaction was successfully captured.\",\"transaction_id\":392442990,\"external_transaction_id\":\"\"}"
  end

  def failed_capture_response; end

  def successful_refund_response; end

  def failed_refund_response; end

  def successful_void_response; end

  def failed_void_response; end
end
