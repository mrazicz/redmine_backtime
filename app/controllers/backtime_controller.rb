class BacktimeController < ApplicationController
  unloadable

  before_filter :member_of_backtime

  def index    
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
    
    # id of current user
    cuser = User.current.id
    # tmp var for sum time and backtime
    tmp_sum1 = Backtime.find(:all, :conditions => ["user_id = ?", cuser]).to_a    
    tmp_sum2 = Backtime.find(:all, :conditions => ["partner_id = ?", cuser]).to_a 

    @time_sum = tmp_sum1.sum(&:time) + tmp_sum2.sum(&:back_time)
    @backtime_sum = tmp_sum1.sum(&:back_time) + tmp_sum2.sum(&:time)
    @backtimes_pages, @backtimes = paginate(:backtime, 
                                            :conditions => ["user_id = ? OR partner_id = ?", cuser, cuser], 
                                            :order => 'created_at desc'
                                           )

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
