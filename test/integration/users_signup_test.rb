require 'test_helper'

class UsersSignupTest < ActionDispatch::IntegrationTest
  
  def setup
    ActionMailer::Base.deliveries.clear
  end
  
  test "invalid signup information" do
    get signup_path
    assert_no_difference 'User.count' do
      post users_path, user: { name:  "",
                               email: "user@invalid",
                               password:              "foo",
                               password_confirmation: "bar" }
    end
    assert_template 'users/new'
  end
  
  test "valid signup information with account activation" do
    get signup_path
    assert_difference 'User.count', 1 do
      post users_path, user: { name:  "Good Name",
                               email: "user@valid.com",
                               password:              "foobar",
                               password_confirmation: "foobar" }
    end
    assert_equal 1, ActionMailer::Base.deliveries.size
    # accessing instance variable user in the control file so we can access its
    # attributes such as activation_token and email.
    user = assigns(:user)
    assert_not user.activated?
    # Try to log in before activation
    log_test_in_as(user)
    assert_not is_test_logged_in?
    # Invalid activation token
    get edit_account_activation_path("invalid token")
    assert_not is_test_logged_in?
    # Valid token, invalid email
    get edit_account_activation_path(user.activation_token, email: "bad")
    assert_not is_test_logged_in?
    # Valid activation token and email
    get edit_account_activation_path(user.activation_token, email: user.email)
    assert user.reload.activated?
    follow_redirect!
    assert_template 'users/show'
    assert is_test_logged_in?
  end
end
