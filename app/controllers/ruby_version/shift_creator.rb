require 'date'
require 'time'
require 'csv'
expect_param = 
{ 
  staff: [{ name: 'Gary', req_off: ['10', '20' ,'25'],
            pay_leave: ['24'], already_working_days: 4,
            last_two_shift: ['M','M']}],
  # managers: [{ name: 'Gary', stable_shift: '', req_off: ['10', '20' ,'25'] }],
  weekday_hr: { morning: 2, afternoon: 2, midnight: 1 },
  weekend_hr: { morning: 1, afternoon: 2, midnight: 1 },
  month: 12
}
class ShiftCreator
  def initialize(param)
    @staff = param[:staff].map { |staff_info| Staff.new(staff_info) }
    # @managers = param[:managers].map { |manager_info| Staff.new(manager_info) }

    @weekday_hr = param[:weekday_hr]
    @weekend_hr = param[:weekend_hr]
    @month = param[:month]
    @priority = {} #{name: integer}
  end

  def create_shift
    return check_params if check_params.is_a?(String)
    return caculate_staff_human_resource[:message] if caculate_staff_human_resource[:hr] < 0
    arrange_midnight_shift
    arrange_shift
    write_to_cvs
  end

  def parse_month
    result = []
    days = Date.new(Time.now.year, @month, -1).day
    for i in (1..days)
      result << "#{i} (#{Time.parse("#{Time.now.year}-#{@month}-#{i}").wday})"
    end

    result
  end

  def check_params
    error_message = ''
    @staff.each_with_index do |staff, index|
      unless staff.name
        error_message << "missing name in staff no.#{index + 1}\n"
      end
    end
    # @managers.each_with_index do |manager, index|
    #   unless manager.name
    #     error_message << "missing name in manager no.#{index + 1}\n"
    #   end
    # end
    error_message << "Missing Month config\n" if @month.nil?
  
    all_shift.each do |shift|
      error_message << "Missing shift config: #{shift}\n" if @weekday_hr[shift.to_sym].nil? || @weekend_hr[shift.to_sym].nil?
    end

    error_message.empty? ? true : error_message
  end

  def caculate_staff_human_resource
    total_staff = @staff.size
    pay_leave = @staff.map { |staff| staff.pay_leave }.reduce(:+).size
    total_weekend = parse_month.grep(/\([6|0]\)/).size
    total_weekday = parse_month.grep(/\([1|2|3|4|5]\)/).size
    weekday_hr = total_weekday * @weekday_hr.values.reduce(:+)
    weekend_hr = total_weekend * @weekend_hr.values.reduce(:+)
    human_resource = total_staff * (parse_month.size - total_weekend) - weekend_hr - weekday_hr - pay_leave
    { message: 'Understaffed, please arrange partime or recruit', hr: human_resource }
    return { message: 'Understaffed, please arrange partime or recruit', hr: human_resource } if human_resource < 0

    { message: 'Sufficient!, please adjust manully', hr: human_resource }
  end

  def arrange_midnight_shift
    assign_info = assign_first_midnight_shift
    unassign_days = parse_month[assign_info[:day]..-1]

    stack = {}
    start_index = 0
    staff = @staff.select {|s| s.name != assign_info[:name]}
    who_will_work = select_shift(staff, start_index, stack, unassign_days)
    # result looks like this
    # {"David"=>["4 (5)", "5 (6)"], "Lucy"=>["13 (0)", "14 (1)"]}
    fail 'unable to auto assign midnight shift' unless who_will_work
    staff.each do |s|
      who_will_work[s.name].each do |date|
        s.journey[date] = 'midnight'
      end
    end
  end

  def arrange_shift
    parse_month.each do |date|
      all_shift.each do |shift|
        @staff.each do |staff|
          staff.midnight_forecast(date)
          if staff.workable?(shift, date)
            staff.send(shift + '_shift_priority')
          else
            staff.priority = 0
          end
        end
        compare_priority_and_arrange_staff(shift, date)
      end
      let_remain_staff_off(date)
    end
  end

  def compare_priority_and_arrange_staff(shift, date)
    on_board_staff_count = date[/\(([6|0])\)/, 1].nil? ? @weekday_hr[shift.to_sym] : @weekend_hr[shift.to_sym]
    who_will_work = @staff.sort_by { |staff| -staff.priority }.slice(0, on_board_staff_count)
    who_will_work.each do |staff|
      staff.journey[date] = shift
      staff.already_working_days += 1
      staff.last_two_shift.slice!(0, 1)
      staff.last_two_shift << shift
    end
  end

  def let_remain_staff_off(date)
    @staff.each do |staff|
      if staff.journey[date].nil?
        staff.journey[date] = 'off'
        staff.already_working_days = 0
        staff.last_two_shift.slice!(0, 1)
        staff.last_two_shift << 'off'
      end
    end
  end

  def write_to_cvs
    CSV.open(File.join(File.dirname(__FILE__), "#{Date::MONTHNAMES[@month]}_roster.csv"), 'wb') do |csv|
      header = parse_month.unshift(Date::MONTHNAMES[@month])
      csv << header
      @staff.each do |staff|
        csv << staff.journey.values.unshift(staff.name)
      end
    end
  end

  def assign_first_midnight_shift
    first_staff = @staff.select { |staff| staff.midnight_count > 0}.first
    first_day_of_month = parse_month.first
    return {day: 0} if first_staff.nil?
    remain_midnight_shift = 5 - first_staff.already_working_days
    first_staff.last_two_shift = ['midnight', 'midnight']
    first_staff.already_working_days = 0
    (0...remain_midnight_shift).each do |range|
      midnight_shift = first_staff.date_range(first_day_of_month, range)
      first_staff.journey[midnight_shift] = 'midnight'
      return {day: range + 1, name: first_staff.name} if remain_midnight_shift - 1 == range
    end
  end

  def select_shift(remaining_staff, start_index, stack, unassign_days)
    remaining_staff.each do |staff|
      if (unassign_days.slice(start_index, 5).map{|s| s[/\d{1,2}/] } & staff.no_midnight_range).empty?
        stack[staff.name] = unassign_days.slice(start_index, 5)
        start_index += 5
        return stack if start_index >= unassign_days.size
        result = select_shift(remaining_staff - [staff], start_index, stack, unassign_days)
        if result == false
          stack[staff.name] = nil
          start_index -= 5
        else
          return result
        end
      end

      if (unassign_days.slice(start_index, 4).map{|s| s[/\d{1,2}/] } & staff.no_midnight_range).empty?
        stack[staff.name] = unassign_days.slice(start_index, 4)
        start_index += 4
        return stack if start_index >= unassign_days.size
        result = select_shift(remaining_staff - [staff], start_index, stack, unassign_days)
        if result == false
          stack[staff.name] = nil
          start_index -= 4
        else
          return result
        end
      end

      next
    end

    false
  end

  private

  def all_shift
    ['morning', 'afternoon']
  end
end
