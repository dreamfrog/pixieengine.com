class UsersController < ResourceController::Base
  actions :all, :except => :destroy

  before_filter :require_user, :only => [:install_plugin]
  before_filter :require_current_user, :only => [:edit, :update, :add_to_collection]

  REGISTERED_FLASH = "Account registered!"

  new_action.before do
    email = session.delete(:email) || ''

    object.email ||= email
    object.display_name = email[0..((email.index('@') || 0) - 1)]
  end

  def remove_favorite
    sprite = Sprite.find(params[:id])
    current_user.remove_favorite(sprite)
    render :nothing => true
  end

  def set_avatar
    sprite = Sprite.find(params[:sprite_id])
    current_user.set_avatar(sprite)
    render :nothing => true
  end

  def register_subscribe
    @object = User.new
  end

  def create
    subscribe = false
    @object = User.new(params[:user])

    @object.referrer_id = session[:referrer_id]

    @object.save do |result|
      if result
        session.delete(:referrer_id)

        bingo!("registration_popup")
        bingo!("load_pic")
        bingo!("login_after")

        save_sprites_to_user(user)

        respond_to do |format|
          format.html do
            @registered = true
            if subscribe
              redirect_to subscribe_path
            else
              redirect_to user, :notice => REGISTERED_FLASH
            end
          end
          format.json { render :json => {:status => "ok"} }
        end

      else
        respond_to do |format|
          format.html do
            if subscribe
              render :action => :register_subscribe
            else
              render :action => :new
            end

          end
          format.json do
            render :json => {
              :status => "error",
              :errors => user.errors.full_messages
            }
          end
        end
      end
    end
  end

  def show
  end

  def add_to_collection
    collectables = [Sprite, Collection, Plugin, Script, User, Library]

    collectable_id = params[:collectable_id].to_i
    collectable_type = params[:collectable_type].constantize
    collection_name = params[:collection_name]

    if collectables.include? collectable_type
      user.add_to_collection(collectable_type.find(collectable_id), collection_name)
    end

    render :nothing => true
  end

  def install_plugin
    current_user.install_plugin(Plugin.find(params[:plugin_id]))

    redirect_to :back, :notice => "Plugin installed"
  end

  def uninstall_plugin
    current_user.uninstall_plugin(Plugin.find(params[:plugin_id]))

    redirect_to :back, :notice => "Plugin uninstalled"
  end

  def do_unsubscribe
    if params[:id]
      user = User.find(params[:id])
    elsif params[:email]
      user = User.find_by_email(params[:email])
    end

    if user
      user.update_attribute(:subscribed, false)
    end

    redirect_to root_path, :notice => "You have been unsubscribed"
  end

  private

  def collection
    users = User

    if filter
      users = users.send(filter)
    end

    @collection ||= users.order("id DESC").paginate(:page => params[:page], :per_page => per_page)
  end

  def require_current_user
    unless current_user?
      redirect_to root_url, :notice => "You can only edit your own account"
    end
  end

  def current_user?
    current_user == object
  end
  helper_method :current_user?

  def object
    return @object if defined?(@object)

    if params[:id] == "current"
      @object = current_user
    else
      @object = User.find(params[:id])
    end
  end

  def user
    object
  end
  helper_method :user

  def users
    collection
  end
  helper_method :users

  def filters
    ["featured", "none"]
  end

  def gallery_filters
    [
      ["Featured", :featured],
      ["All", :none],
    ]
  end
  helper_method :gallery_filters
end
