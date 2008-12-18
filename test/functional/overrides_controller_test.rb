require 'test_helper'

class OverridesControllerTest < ActionController::TestCase
  def test_should_get_index
    get :index
    assert_response :success
    assert_not_nil assigns(:overrides)
  end

  def test_should_get_new
    get :new
    assert_response :success
  end

  def test_should_create_override
    assert_difference('Override.count') do
      post :create, :override => { }
    end

    assert_redirected_to override_path(assigns(:override))
  end

  def test_should_show_override
    get :show, :id => overrides(:one).id
    assert_response :success
  end

  def test_should_get_edit
    get :edit, :id => overrides(:one).id
    assert_response :success
  end

  def test_should_update_override
    put :update, :id => overrides(:one).id, :override => { }
    assert_redirected_to override_path(assigns(:override))
  end

  def test_should_destroy_override
    assert_difference('Override.count', -1) do
      delete :destroy, :id => overrides(:one).id
    end

    assert_redirected_to overrides_path
  end
end
