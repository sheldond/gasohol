require 'test_helper'

class FlagsControllerTest < ActionController::TestCase
  def test_should_get_index
    get :index
    assert_response :success
    assert_not_nil assigns(:flags)
  end

  def test_should_get_new
    get :new
    assert_response :success
  end

  def test_should_create_flags
    assert_difference('Flags.count') do
      post :create, :flags => { }
    end

    assert_redirected_to flags_path(assigns(:flags))
  end

  def test_should_show_flags
    get :show, :id => flags(:one).id
    assert_response :success
  end

  def test_should_get_edit
    get :edit, :id => flags(:one).id
    assert_response :success
  end

  def test_should_update_flags
    put :update, :id => flags(:one).id, :flags => { }
    assert_redirected_to flags_path(assigns(:flags))
  end

  def test_should_destroy_flags
    assert_difference('Flags.count', -1) do
      delete :destroy, :id => flags(:one).id
    end

    assert_redirected_to flags_path
  end
end
