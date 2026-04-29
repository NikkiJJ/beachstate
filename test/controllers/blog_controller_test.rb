require "test_helper"

class BlogControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get blog_url
    assert_response :success
  end

  test "should get show" do
    get blog_post_url(slug: "test-post")
    assert_response :success
  end
end
