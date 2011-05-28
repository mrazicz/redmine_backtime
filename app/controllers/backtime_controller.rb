class BacktimeController < ApplicationController
  #unloadable

  before_filter :get_users

  def index
    @time_sum = Backtime.sum('Time')
    @backtime_sum = Backtime.sum('Back_time')
    @backtimes_pages, @backtimes = paginate(:backtime, :order => 'created_at desc')
    
    @backtime = Backtime.new
  end

  def add
    @backtime = Backtime.new(params[:backtime])
    if @backtime.save
      flash[:notice] = 'Post was successfully saved.'
      redirect_to :action => :index
    else
      flash[:error] = @backtime.errors.full_messages.join("<br />")
      redirect_to :action => :index
    end
  end
  
  private
  
  def get_users
    @users_list = Group.find_by_lastname("BackTime").users.map {
      |u| [u.lastname + ' ' + u.firstname, u.id]
    }
  end
end
