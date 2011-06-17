class Hooks < Redmine::Hook::ViewListener
    
  def view_timelog_edit_form_bottom(context = {})
    if User.current.group_ids.include?(Group.find_by_lastname("BackTime").id)
      users_list = Group.find_by_lastname("BackTime").users.all(:conditions => ["id != ?", User.current.id]).collect {
                          |u| [u.lastname + ' ' + u.firstname, u.id]
                        }

      selected = context[:time_entry].backtime.partner_id unless context[:time_entry].backtime.nil?
      checked = "checked='checked'" unless context[:time_entry].backtime.nil?
      display = "style='display: none;'" if checked.nil?

      backtime_form = context[:form].fields_for :backtime_attributes do |b|
        b.select :partner_id, users_list, :selected => selected
      end

      return "
        <p>
          #{label 'backtime_time', 'BackTime'}
          <input name='backtime_time' type='checkbox' #{checked} onchange='$(\"backtime-time\").toggle()' />
        </p>
        <p id='backtime-time' #{display}>#{backtime_form}</p>"
    else
      return ''
    end
  end

  def controller_timelog_edit_before_save(context = {})
    te = context[:time_entry]
    tep = context[:params]
       
    if !te.nil? && !tep[:time_entry].nil? && !tep["backtime_time"].nil?
      te.build_backtime({}) if te.backtime.nil?
      te.backtime_attributes = {:partner_id => tep[:time_entry][:backtime_attributes][:partner_id], 
                                :user_id => User.current.id, 
                                :back_time => 0, 
                                :time => te[:hours],
                                :description => "#{te[:comments]} (<a href='/issues/#{te[:issue_id]}'>#{te.issue.subject}</a>)"
                               }
    elsif !tep.nil? && tep["backtime_time"].nil?
      te.backtime.delete unless te.backtime.nil?
    end
  end
end

