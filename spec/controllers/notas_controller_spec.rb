require 'spec_helper'

# This spec was generated by rspec-rails when you ran the scaffold generator.
# It demonstrates how one might use RSpec to specify the controller code that
# was generated by the Rails when you ran the scaffold generator.

describe NotasController do

  def mock_nota(stubs={})
    @mock_nota ||= mock_model(Nota, stubs).as_null_object
  end

  describe "GET index" do
    it "assigns all notas as @notas" do
      Nota.stub(:all) { [mock_nota] }
      get :index
      assigns(:notas).should eq([mock_nota])
    end
  end

  describe "GET show" do
    it "assigns the requested nota as @nota" do
      Nota.stub(:find).with("37") { mock_nota }
      get :show, :id => "37"
      assigns(:nota).should be(mock_nota)
    end
  end

  describe "GET new" do
    it "assigns a new nota as @nota" do
      Nota.stub(:new) { mock_nota }
      get :new
      assigns(:nota).should be(mock_nota)
    end
  end

  describe "GET edit" do
    it "assigns the requested nota as @nota" do
      Nota.stub(:find).with("37") { mock_nota }
      get :edit, :id => "37"
      assigns(:nota).should be(mock_nota)
    end
  end

  describe "POST create" do
    describe "with valid params" do
      it "assigns a newly created nota as @nota" do
        Nota.stub(:new).with({'these' => 'params'}) { mock_nota(:save => true) }
        post :create, :nota => {'these' => 'params'}
        assigns(:nota).should be(mock_nota)
      end

      it "redirects to the created nota" do
        Nota.stub(:new) { mock_nota(:save => true) }
        post :create, :nota => {}
        response.should redirect_to(nota_url(mock_nota))
      end
    end

    describe "with invalid params" do
      it "assigns a newly created but unsaved nota as @nota" do
        Nota.stub(:new).with({'these' => 'params'}) { mock_nota(:save => false) }
        post :create, :nota => {'these' => 'params'}
        assigns(:nota).should be(mock_nota)
      end

      it "re-renders the 'new' template" do
        Nota.stub(:new) { mock_nota(:save => false) }
        post :create, :nota => {}
        response.should render_template("new")
      end
    end
  end

  describe "PUT update" do
    describe "with valid params" do
      it "updates the requested nota" do
        Nota.stub(:find).with("37") { mock_nota }
        mock_nota.should_receive(:update_attributes).with({'these' => 'params'})
        put :update, :id => "37", :nota => {'these' => 'params'}
      end

      it "assigns the requested nota as @nota" do
        Nota.stub(:find) { mock_nota(:update_attributes => true) }
        put :update, :id => "1"
        assigns(:nota).should be(mock_nota)
      end

      it "redirects to the nota" do
        Nota.stub(:find) { mock_nota(:update_attributes => true) }
        put :update, :id => "1"
        response.should redirect_to(nota_url(mock_nota))
      end
    end

    describe "with invalid params" do
      it "assigns the nota as @nota" do
        Nota.stub(:find) { mock_nota(:update_attributes => false) }
        put :update, :id => "1"
        assigns(:nota).should be(mock_nota)
      end

      it "re-renders the 'edit' template" do
        Nota.stub(:find) { mock_nota(:update_attributes => false) }
        put :update, :id => "1"
        response.should render_template("edit")
      end
    end
  end

  describe "DELETE destroy" do
    it "destroys the requested nota" do
      Nota.stub(:find).with("37") { mock_nota }
      mock_nota.should_receive(:destroy)
      delete :destroy, :id => "37"
    end

    it "redirects to the notas list" do
      Nota.stub(:find) { mock_nota }
      delete :destroy, :id => "1"
      response.should redirect_to(notas_url)
    end
  end

end
