class Querybacktime < ActiveRecord::Base
  class StatementInvalid < ::ActiveRecord::StatementInvalid
  end

  belongs_to :project
  belongs_to :user
  serialize :filters
  serialize :column_names
  serialize :sort_criteria, Array

	attr_protected :project_id, :user_id

  validates_presence_of :name, :on => :save
  validates_length_of :name, :maximum => 255
  validate :validate_query_filters

  @@operators = { "="   => :label_equals,
                  "!"   => :label_not_equals,
                  "o"   => :label_open_issues,
                  "c"   => :label_closed_issues,
                  "!*"  => :label_none,
                  "*"   => :label_all,
                  ">="  => :label_greater_or_equal,
                  "<="  => :label_less_or_equal,
                  "><"  => :label_between,
                  "<t+" => :label_in_less_than,
                  ">t+" => :label_in_more_than,
                  "t+"  => :label_in,
                  "t"   => :label_today,
                  "w"   => :label_this_week,
                  ">t-" => :label_less_than_ago,
                  "<t-" => :label_more_than_ago,
                  "t-"  => :label_ago,
                  "~"   => :label_contains,
                  "!~"  => :label_not_contains }

  cattr_reader :operators

  @@operators_by_filter_type = { :list => [ "=", "!" ],
                                 :list_status => [ "o", "=", "!", "c", "*" ],
                                 :list_optional => [ "=", "!", "!*", "*" ],
                                 :list_subprojects => [ "*", "!*", "=" ],
                                 :date => [ "=", ">=", "<=", "><", "<t+", ">t+", "t+", "t", "w", ">t-", "<t-", "t-", "!*", "*" ],
                                 :date_past => [ "=", ">=", "<=", "><", ">t-", "<t-", "t-", "t", "w", "!*", "*" ],
                                 :string => [ "=", "~", "!", "!~" ],
                                 :text => [  "~", "!~" ],
                                 :integer => [ "=", ">=", "<=", "><", "!*", "*" ],
                                 :float => [ "=", ">=", "<=", "><", "!*", "*" ] }

  cattr_reader :operators_by_filter_type

  @@available_columns = [
    QueryColumn.new(:time, :sortable => "#{Backtime.table_name}.time"),
    QueryColumn.new(:back_time, :sortable => "#{Backtime.table_name}.back_time"),
    QueryColumn.new(:user, :sortable => "#{Backtime.table_name}.user"),
    QueryColumn.new(:partner, :sortable => "#{Backtime.table_name}.partner"),
    QueryColumn.new(:description, :sortable => "#{Backtime.table_name}.description"),
    QueryColumn.new(:created_at, :sortable => "#{Backtime.table_name}.created_at", :default_order => 'desc'),
  ]
  cattr_reader :available_columns

  def initialize (attributes = nil) 
    super attributes
  end

  def after_initialize
    # Store the fact that project is nil (used in #editable_by?)
    @is_for_all = project.nil?
  end

  def validate_query_filters
    filters.each_key do |field|
      if values_for(field)
        case type_for(field)
        when :integer
          errors.add(label_for(field), :invalid) if values_for(field).detect {|v| v.present? && !v.match(/^\d+$/) }
        when :float
          errors.add(label_for(field), :invalid) if values_for(field).detect {|v| v.present? && !v.match(/^\d+(\.\d*)?$/) }
        when :date, :date_past
          case operator_for(field)
          when "=", ">=", "<=", "><"
            errors.add(label_for(field), :invalid) if values_for(field).detect {|v| v.present? && (!v.match(/^\d{4}-\d{2}-\d{2}$/) || (Date.parse(v) rescue nil).nil?) }
          when ">t-", "<t-", "t-"
            errors.add(label_for(field), :invalid) if values_for(field).detect {|v| v.present? && !v.match(/^\d+$/) }
          end
        end
      end

      errors.add label_for(field), :blank unless
          # filter requires one or more values
          (values_for(field) and !values_for(field).first.blank?) or
          # filter doesn't require any value
          ["o", "c", "!*", "*", "t", "w"].include? operator_for(field)
    end if filters
  end

  # Returns true if the query is visible to +user+ or the current user.
  def visible?(user=User.current)
    (project.nil? || user.allowed_to?(:view_issues, project)) && (self.is_public? || self.user_id == user.id)
  end

  def editable_by?(user)
    return false unless user
    # Admin can edit them all and regular users can edit their private queries
    return true if user.admin? || (!is_public && self.user_id == user.id)
    # Members can not edit public queries that are for all project (only admin is allowed to)
    is_public && !@is_for_all && user.allowed_to?(:manage_public_queries, project)
  end

  def available_filters
    return @available_filters if @available_filters

#ts "values: "+filters["partner_id"][:values]
    @available_filters = { "time" => { :type => :float, :order => 2, :name => l(:label_time) },
                           "back_time" => { :type => :float, :order => 3, :name => l(:label_back_time) },
                           "created_at" => { :type => :date_past, :order => 9, :name => l(:label_date) },
                           "partner_id" => { :type => :list, :order => 8, :name => l(:label_partner), :values => Group.find_by_lastname('Backtime').users.all.map! {|u| [u.lastname + ' ' + u.firstname, u.id]} },
                           }

    @available_filters
  end

  def add_filter(field, operator, values)
    # values must be an array
    return unless values.nil? || values.is_a?(Array)
    # check if field is defined as an available filter
    if available_filters.has_key? field
      filter_options = available_filters[field]
      # check if operator is allowed for that filter
      #if @@operators_by_filter_type[filter_options[:type]].include? operator
      #  allowed_values = values & ([""] + (filter_options[:values] || []).collect {|val| val[1]})
      #  filters[field] = {:operator => operator, :values => allowed_values } if (allowed_values.first and !allowed_values.first.empty?) or ["o", "c", "!*", "*", "t"].include? operator
      #end
      filters[field] = {:operator => operator, :values => (values || [''])}
    end
  end

  def add_short_filter(field, expression)
    return unless expression && available_filters.has_key?(field)
    field_type = available_filters[field][:type]
    @@operators_by_filter_type[field_type].sort.reverse.detect do |operator|
      next unless expression =~ /^#{Regexp.escape(operator)}(.*)$/
      add_filter field, operator, $1.present? ? $1.split('|') : ['']
    end || add_filter(field, '=', expression.split('|'))
  end

  # Add multiple filters using +add_filter+
  def add_filters(fields, operators, values)
    if fields.is_a?(Array) && operators.is_a?(Hash) && (values.nil? || values.is_a?(Hash))
      fields.each do |field|
        add_filter(field, operators[field], values && values[field])
      end
    end
  end

  def has_filter?(field)
    filters and filters[field]
  end

  def type_for(field)
    available_filters[field][:type] if available_filters.has_key?(field)
  end

  def operator_for(field)
    has_filter?(field) ? filters[field][:operator] : nil
  end

  def values_for(field)
    has_filter?(field) ? filters[field][:values] : nil
  end

  def value_for(field, index=0)
    (values_for(field) || [])[index]
  end

  def label_for(field)
    label = available_filters[field][:name] if available_filters.has_key?(field)
    label ||= field.gsub(/\_id$/, "")
  end

  def available_columns
    return @available_columns if @available_columns
    @available_columns = ::Querybacktime.available_columns
    @available_columns += (project ?
                            project.all_issue_custom_fields :
                            IssueCustomField.find(:all)
                           ).collect {|cf| QueryCustomFieldColumn.new(cf) }
  end
 
  def self.add_available_column(column)
    self.available_columns << (column) if column.is_a?(QueryColumn)
  end

  # Returns an array of columns that can be used to group the results
  def groupable_columns
    available_columns.select {|c| c.groupable}
  end

  # Returns a Hash of columns and the key for sorting
  def sortable_columns
    {'id' => "#{Issue.table_name}.id"}.merge(available_columns.inject({}) {|h, column|
                                               h[column.name.to_s] = column.sortable
                                               h
                                             })
  end

  def columns
    # preserve the column_names order
    (has_default_columns? ? default_columns_names : column_names).collect do |name|
       available_columns.find { |col| col.name == name }
    end.compact
  end

  def default_columns_names
    @default_columns_names ||= begin
      default_columns = Setting.issue_list_default_columns.map(&:to_sym)

      project.present? ? default_columns : [:project] | default_columns
    end
  end

  def column_names=(names)
    if names
      names = names.select {|n| n.is_a?(Symbol) || !n.blank? }
      names = names.collect {|n| n.is_a?(Symbol) ? n : n.to_sym }
      # Set column_names to nil if default columns
      if names == default_columns_names
        names = nil
      end
    end
    write_attribute(:column_names, names)
  end

  def has_column?(column)
    column_names && column_names.include?(column.name)
  end

  def has_default_columns?
    column_names.nil? || column_names.empty?
  end

  def sort_criteria=(arg)
    c = []
    if arg.is_a?(Hash)
      arg = arg.keys.sort.collect {|k| arg[k]}
    end
    c = arg.select {|k,o| !k.to_s.blank?}.slice(0,3).collect {|k,o| [k.to_s, o == 'desc' ? o : 'asc']}
    write_attribute(:sort_criteria, c)
  end

  def sort_criteria
    read_attribute(:sort_criteria) || []
  end

  def sort_criteria_key(arg)
    sort_criteria && sort_criteria[arg] && sort_criteria[arg].first
  end

  def sort_criteria_order(arg)
    sort_criteria && sort_criteria[arg] && sort_criteria[arg].last
  end

  # Returns the SQL sort order that should be prepended for grouping
  def group_by_sort_order
    if grouped? && (column = group_by_column)
      column.sortable.is_a?(Array) ?
        column.sortable.collect {|s| "#{s} #{column.default_order}"}.join(',') :
        "#{column.sortable} #{column.default_order}"
    end
  end

  # Returns true if the query is a grouped query
  def grouped?
    !group_by_column.nil?
  end

  def group_by_column
    groupable_columns.detect {|c| c.groupable && c.name.to_s == group_by}
  end

  def group_by_statement
    group_by_column.try(:groupable)
  end

	#returns sql filter statement
	#+options+ :partner_position indicates substitution of "partner_id"->"user_id" and "time"->"back_time" and vice versa
  def bt_filters(options)
    filters_clauses = []
    filters.each_key do |field|
      v = values_for(field).clone
      next unless v and !v.empty?
      operator = operator_for(field)

      if field =~ /^cf_(\d+)$/
        # custom field
        filters_clauses << sql_for_custom_field(field, operator, v, $1)
      elsif respond_to?("sql_for_#{field}_field")
        # specific statement
        filters_clauses << send("sql_for_#{field}_field", field, operator, v)
      else
        # regular field
        filters_clauses << '(' + sql_for_field(field, operator, v, Backtime.table_name, field) + ')'
      end
      if (options[:partner_position]==true)
				filters_clauses.last.gsub!("#{Backtime.table_name}.partner_id", "#{Backtime.table_name}.user_id") or filters_clauses.last.gsub!("#{Backtime.table_name}.user_id", "#{Backtime.table_name}.partner_id")
				filters_clauses.last.gsub!("#{Backtime.table_name}.time", "#{Backtime.table_name}.back_time") or filters_clauses.last.gsub!("#{Backtime.table_name}.back_time", "#{Backtime.table_name}.time")
			end
    end if filters and valid?

    filters_clauses.reject!(&:blank?)
    
    filters_clauses.any? ? filters_clauses.join(' AND ') : nil
  end

  def values_for(field)
    has_filter?(field) ? filters[field][:values] : nil
  end

  def value_for(field, index=0)
    (values_for(field) || [])[index]
  end
  
  def type_for(field)
    available_filters[field][:type] if available_filters.has_key?(field)
  end

  private

  def sql_for_custom_field(field, operator, value, custom_field_id)
    db_table = CustomValue.table_name
    db_field = 'value'
    "#{Issue.table_name}.id IN (SELECT #{Issue.table_name}.id FROM #{Issue.table_name} LEFT OUTER JOIN #{db_table} ON #{db_table}.customized_type='Issue' AND #{db_table}.customized_id=#{Issue.table_name}.id AND #{db_table}.custom_field_id=#{custom_field_id} WHERE " +
      sql_for_field(field, operator, value, db_table, db_field, true) + ')'
  end

  # Helper method to generate the WHERE sql for a +field+, +operator+ and a +value+
  def sql_for_field(field, operator, value, db_table, db_field, is_custom_filter=false)
    sql = ''
    case operator
    when "="
      if value.any?
        case type_for(field)
        when :date, :date_past
          sql = date_clause(db_table, db_field, (Date.parse(value.first) rescue nil), (Date.parse(value.first) rescue nil))
        when :integer
          sql = "#{db_table}.#{db_field} = #{value.first.to_i}"
        when :float
          sql = "#{db_table}.#{db_field} BETWEEN #{value.first.to_f - 1e-5} AND #{value.first.to_f + 1e-5}"
        else
          sql = "#{db_table}.#{db_field} IN (" + value.collect{|val| "'#{connection.quote_string(val)}'"}.join(",") + ")"
        end
      else
        # IN an empty set
        sql = "1=0"
      end
    when "!"
      if value.any?
        sql = "(#{db_table}.#{db_field} IS NULL OR #{db_table}.#{db_field} NOT IN (" + value.collect{|val| "'#{connection.quote_string(val)}'"}.join(",") + "))"
      else
        # NOT IN an empty set
        sql = "1=1"
      end
    when "!*"
      sql = "#{db_table}.#{db_field} IS NULL"
      sql << " OR #{db_table}.#{db_field} = ''" if is_custom_filter
    when "*"
      sql = "#{db_table}.#{db_field} IS NOT NULL"
      sql << " AND #{db_table}.#{db_field} <> ''" if is_custom_filter
    when ">="
      if [:date, :date_past].include?(type_for(field))
        sql = date_clause(db_table, db_field, (Date.parse(value.first) rescue nil), nil)
      else
        if is_custom_filter
          sql = "CAST(#{db_table}.#{db_field} AS decimal(60,3)) >= #{value.first.to_f}"
        else
          sql = "#{db_table}.#{db_field} >= #{value.first.to_f}"
        end
      end
    when "<="
      if [:date, :date_past].include?(type_for(field))
        sql = date_clause(db_table, db_field, nil, (Date.parse(value.first) rescue nil))
      else
        if is_custom_filter
          sql = "CAST(#{db_table}.#{db_field} AS decimal(60,3)) <= #{value.first.to_f}"
        else
          sql = "#{db_table}.#{db_field} <= #{value.first.to_f}"
        end
      end
    when "><"
      if [:date, :date_past].include?(type_for(field))
        sql = date_clause(db_table, db_field, (Date.parse(value[0]) rescue nil), (Date.parse(value[1]) rescue nil))
      else
        if is_custom_filter
          sql = "CAST(#{db_table}.#{db_field} AS decimal(60,3)) BETWEEN #{value[0].to_f} AND #{value[1].to_f}"
        else
          sql = "#{db_table}.#{db_field} BETWEEN #{value[0].to_f} AND #{value[1].to_f}"
        end
      end
    when "o"
      sql = "#{IssueStatus.table_name}.is_closed=#{connection.quoted_false}" if field == "status_id"
    when "c"
      sql = "#{IssueStatus.table_name}.is_closed=#{connection.quoted_true}" if field == "status_id"
    when ">t-"
      sql = relative_date_clause(db_table, db_field, - value.first.to_i, 0)
    when "<t-"
      sql = relative_date_clause(db_table, db_field, nil, - value.first.to_i)
    when "t-"
      sql = relative_date_clause(db_table, db_field, - value.first.to_i, - value.first.to_i)
    when ">t+"
      sql = relative_date_clause(db_table, db_field, value.first.to_i, nil)
    when "<t+"
      sql = relative_date_clause(db_table, db_field, 0, value.first.to_i)
    when "t+"
      sql = relative_date_clause(db_table, db_field, value.first.to_i, value.first.to_i)
    when "t"
      sql = relative_date_clause(db_table, db_field, 0, 0)
    when "w"
      first_day_of_week = l(:general_first_day_of_week).to_i
      day_of_week = Date.today.cwday
      days_ago = (day_of_week >= first_day_of_week ? day_of_week - first_day_of_week : day_of_week + 7 - first_day_of_week)
      sql = relative_date_clause(db_table, db_field, - days_ago, - days_ago + 6)
    when "~"
      sql = "LOWER(#{db_table}.#{db_field}) LIKE '%#{connection.quote_string(value.first.to_s.downcase)}%'"
    when "!~"
      sql = "LOWER(#{db_table}.#{db_field}) NOT LIKE '%#{connection.quote_string(value.first.to_s.downcase)}%'"
    else
      raise "Unknown query operator #{operator}"
    end

    return sql
  end

  def add_custom_fields_filters(custom_fields)
    @available_filters ||= {}

    custom_fields.select(&:is_filter?).each do |field|
      case field.field_format
      when "text"
        options = { :type => :text, :order => 20 }
      when "list"
        options = { :type => :list_optional, :values => field.possible_values, :order => 20}
      when "date"
        options = { :type => :date, :order => 20 }
      when "bool"
        options = { :type => :list, :values => [[l(:general_text_yes), "1"], [l(:general_text_no), "0"]], :order => 20 }
      when "int"
        options = { :type => :integer, :order => 20 }
      when "float"
        options = { :type => :float, :order => 20 }
      when "user", "version"
        next unless project
        options = { :type => :list_optional, :values => field.possible_values_options(project), :order => 20}
      else
        options = { :type => :string, :order => 20 }
      end
      @available_filters["cf_#{field.id}"] = options.merge({ :name => field.name })
    end
  end

  # Returns a SQL clause for a date or datetime field.
  def date_clause(table, field, from, to)
    s = []
    if from
      from_yesterday = from - 1
      from_yesterday_utc = Time.gm(from_yesterday.year, from_yesterday.month, from_yesterday.day)
      s << ("#{table}.#{field} > '%s'" % [connection.quoted_date(from_yesterday_utc.end_of_day)])
    end
    if to
      to_utc = Time.gm(to.year, to.month, to.day)
      s << ("#{table}.#{field} <= '%s'" % [connection.quoted_date(to_utc.end_of_day)])
    end
    s.join(' AND ')
  end

  # Returns a SQL clause for a date or datetime field using relative dates.
  def relative_date_clause(table, field, days_from, days_to)
    date_clause(table, field, (days_from ? Date.today + days_from : nil), (days_to ? Date.today + days_to : nil))
  end
  
end
