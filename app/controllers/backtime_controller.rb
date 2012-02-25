class BacktimeController < ApplicationController
  unloadable

  before_filter :member_of_backtime, :check_db_backtime

  helper :queries
  include QueriesHelper
  helper :sort
  include SortHelper
  
  
  def index
    retrieve_querybacktime
    sort_init(@query.sort_criteria.empty? ? [['created_at', 'desc']] : @query.sort_criteria)
    sort_update( @query.sortable_columns )
   
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

    backtimes_with_issue_user_position = Backtime.all(:select => "backtimes.*, SUM(backtimes.time) as times",
                                         :conditions => "time_entry_id IS NOT NULL AND backtimes.user_id = #{cuser}" + ((@query.bt_filters(:partner_position=>false).nil?) ? "" : " AND #{@query.bt_filters(:partner_position=>false).to_s}" ),
                                         :joins => "LEFT JOIN time_entries AS te ON te.id = time_entry_id",
                                         :group => 'te.issue_id')
    backtimes_with_issue_partner_position = Backtime.all(:select => "backtimes.*, SUM(backtimes.time) as times",
                                         :conditions => "time_entry_id IS NOT NULL AND backtimes.user_id = #{cuser}" + ((@query.bt_filters(:partner_position=>true).nil?) ? "" : " AND #{@query.bt_filters(:partner_position=>true).to_s}" ),
                                         :joins => "LEFT JOIN time_entries AS te ON te.id = time_entry_id",
                                         :group => 'te.issue_id')
                                         
    backtimes_without_issue_user_position = Backtime.all(	:select => "backtimes.*",
    																				:conditions => "time_entry_id IS NULL AND backtimes.user_id = #{cuser}" + ((@query.bt_filters(:partner_position=>false).nil?) ? "" : " AND #{@query.bt_filters(:partner_position=>false).to_s}" ))
    backtimes_without_issue_partner_position = Backtime.all(	:select => "backtimes.*",
    																				:conditions => "time_entry_id IS NULL AND backtimes.partner_id = #{cuser}" + ((@query.bt_filters(:partner_position=>true).nil?) ? "" : " AND #{@query.bt_filters(:partner_position=>true).to_s}") )
		
    backtimes_all = backtimes_without_issue_partner_position + backtimes_without_issue_user_position + backtimes_with_issue_user_position + backtimes_with_issue_partner_position
    
    backtimes_all.each do |b|
      unless b['times'].nil?
        b['time'] = b['times']
        b['description'] = "<a href='/issues/#{b.time_entry.issue_id}'> ##{b.time_entry.issue_id}</a>: "
        b['description'] += b.time_entry.issue.subject
        b['description'] += " [<a href='/projects/#{b.time_entry.issue.project.identifier}'>#{b.time_entry.issue.project.name}</a>]"
      end
    end
    
		backtimes_all.each{ |b|
			if b['partner_id'] == cuser
				b['user_id'], b["partner_id"] = b['partner_id'], b["user_id"]
				b['time'], b['back_time'] = b['back_time'], b['time']
			end
    }
    
    @sort_criteria.criteria.reverse.each{ |c, o|
    	backtimes_all = backtimes_all.sort_by(&c.to_sym)
    	backtimes_all.reverse! unless o 
    }
    
    # paginate results
    @backtimes_count = backtimes_all.size
    @backtimes_pages = Paginator.new self, @backtimes_count, per_page_option, params['page']
    limit = @backtimes_pages.items_per_page
    offset = @backtimes_pages.current.offset
    @backtimes = backtimes_all[offset..offset+limit]

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

  def check_db_backtime
    null_times = Backtime.find_all_by_time(nil)
    null_times.each do |nt|
      nt.update_attribute(:time, 0)
    end
    null_backtimes = Backtime.find_all_by_back_time(nil)
    null_backtimes.each do |nbt|
      nbt.update_attribute(:back_time, 0)
    end
  end
end

