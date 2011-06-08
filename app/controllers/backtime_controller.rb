class BacktimeController < ApplicationController
  unloadable

  before_filter :member_of_backtime

  def index    
    #@users_list = User.all(:select => 'users.*, SUM(backtimes.back_time) as backtime_total',
    #                        :joins => [:groups], 
    #                        :include => [:backtimes], 
    #                        :conditions => ["users.id != ? AND groups_users.lastname = ?", User.current.id, "Backtime"], 
    #                        :order => 'backtime_total desc'
    #                       )
    
    @users_list = Group.find_by_lastname('Backtime').users.all(:select => "users.*, SUM(backtimes.time) as times_total",
                           :joins => "LEFT JOIN backtimes AS backtimes ON backtimes.partner_id = users.id",
                           :group => "users.id",
                           :conditions => ["users.id != ?", User.current.id], 
                           :order => "times_total DESC"
                          )
    
    unless @users_list.nil?
      @users_list.map! {
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
    @backtime.user_id = User.current.id
    if @backtime.save
      flash[:notice] = l(:post_saved)
      redirect_to :action => :index
    else
      flash[:error] = @backtime.errors.full_messages.join("<br />")
      redirect_to :action => :index
    end
  end

  private

  def member_of_backtime
    unless User.current.admin? || User.current.group_ids.include?(Group.find_by_lastname("BackTime").id)
      render_403
    end
  end
end
