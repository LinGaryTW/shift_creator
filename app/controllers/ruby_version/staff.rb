class Staff
  attr_accessor :journey, :already_working_days, :last_two_shift, :priority, :name, :req_off, :pay_leave, :no_midnight_range, :midnight_count
  def initialize(info)
    @name = info[:name]
    @pay_leave = info[:pay_leave] || []
    req_off = info[:req_off] || []
    @req_off = req_off + @pay_leave
    @already_working_days = info[:already_working_days] || 0
    @last_two_shift = info[:last_two_shift] || ['off', 'off']
    @journey = {}
    @priority = 0
    @midnight_count = info[:midnight_count] || 0
    @no_midnight_range = set_up_no_midnight(**(info[:no_midnight_range] || {}))
  end

  def workable?(shift, date)
    # becase after assign shift will increase working days count
    # if we increase someone to 5 when arranging morning shift
    # then he/she would be set to off when check workable when arrange morning shift
    # morning -> workable? -> arrange shift -> afternoon -> workable? #may set 'off' here
    if @journey[date] == 'off'
      @already_working_days = 0
      return false
    end
    return false unless @journey[date].nil?
    return false if midnight_forecast(date)

    if @already_working_days >= 4 || @req_off.include?(date.scan(/\d{1,2}/).first)
      @journey[date] = 'off'
      @already_working_days = 0
      @last_two_shift.slice!(0, 1)
      @last_two_shift << 'off'
      return false
    end

    true
  end

  def midnight_shift_priority
    self.priority = if last_two_shift[1] == 'midnight'
                      3 + already_working_days
                    elsif last_two_shift == ['off', 'off']
                      2
                    elsif last_two_shift == ['afternoon', 'off']
                      1
                    else
                      0
                    end
  end

  def morning_shift_priority
    self.priority = if last_two_shift[1] == 'morning'
                      3 + already_working_days
                    elsif last_two_shift == ['off', 'off']
                      2
                    elsif last_two_shift == ['morning', 'off'] || last_two_shift == ['afternoon', 'off']
                      1
                    else
                      0
                    end
  end

  def afternoon_shift_priority
    self.priority = if last_two_shift[1] == 'afternoon'
                      4 + already_working_days
                    elsif last_two_shift == ['off', 'off']
                      3
                    elsif last_two_shift == ['morning', 'off'] || last_two_shift == ['afternoon', 'off']
                      2
                    elsif last_two_shift[1] == 'morning'
                      1
                    else
                      0
                    end
  end

  # if staff have midnight two days later, turn today and tomorrow to 'off'
  def midnight_forecast(date)
    if @journey[date_range(date, 2)] == 'midnight'
      if last_two_shift[1] == 'morning'
        @journey[date] = 'off'
        @journey[date_range(date, 1)] = 'off'
        @last_two_shift = ['off', 'off']
      elsif last_two_shift[1] == 'afternoon'
        if already_working_days <= 2
          @journey[date_range(date, 1)] = 'off'
        else
          @journey[date] = 'off'
          @journey[date_range(date, 1)] = 'off'
          @last_two_shift = ['off', 'off']
        end
      end

      return true
    end

    false
  end

  def date_range(date, range)
    date.gsub(/(\d)\ \((\d)\)/) do
      day = $1.to_i
      forecast_date = $2.to_i + range
      "#{(day + range)} (#{forecast_date > 6 ? forecast_date % 7 : forecast_date})"
    end
  end

  def set_up_no_midnight(back: -3, forecast: 3)
    block_days = []
    @req_off.each do |date|
      (back..forecast).each do |range|
        block_days << "#{date.to_i + range}"
      end
    end

    block_days.uniq
  end
end
