class BacktimeController < ApplicationController
  unloadable

  def index    
    @users_list = Group.find_by_lastname("BackTime")
    unless @users_list.nil?
      @users_list = @users_list.users.map {
        |u| [u.lastname + ' ' + u.firstname, u.id]
      }
    end
    
    @time_sum = Backtime.sum('Time')
    @backtime_sum = Backtime.sum('Back_time')
    @backtimes_pages, @backtimes = paginate(:backtime, :order => 'created_at desc')
    
    @backtime = Backtime.new
  end

  def add
    @backtime = Backtime.new(params[:backtime])
    if @backtime.save
      flash[:notice] = l(:post_saved)
      redirect_to :action => :index
    else
      flash[:error] = @backtime.errors.full_messages.join("<br />")
      redirect_to :action => :index
    end
  end
end
