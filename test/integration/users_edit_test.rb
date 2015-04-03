require 'test_helper'

class UsersEditTest < ActionDispatch::IntegrationTest
  
  def setup
    @user = users(:michael)
  end
  
  test "unsuccessful edit" do
    log_test_in_as(@user)
    get edit_user_path(@user)
    assert_template "users/edit"
    patch user_path(@user), user: { name: "",
                                   email: "bad@invalid",
                                   password: "doesn't",
                                   password_confirmation: "match" }
    assert_template "users/edit"
  end
  
  test "successful edit with friendly forwarding" do
    get edit_user_path(@user)
    log_test_in_as(@user)
    assert_redirected_to edit_user_path(@user)
    name = "Good Name"
    email = "good@valid.com"
    patch user_path(@user), user: { name: name,
                                   email: email,
                                   password: "",
                                   password_confirmation: "" }
    assert_not flash.empty?
    assert_redirected_to @user
    @user.reload
    assert_equal @user.name, name
    assert_equal @user.email, email
  end
end
