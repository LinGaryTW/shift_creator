require "test/unit"
require './staff.rb'

class StaffTest < Test::Unit::TestCase
  def test_workable?
    staff = create_staff( last_two_shift: ['off', 'morning'], pay_leave: ['24'], already_working_days: 1)
    assert_true(staff.workable?('morning', "29 (6)"))
    assert_equal(staff.already_working_days, 1)
    assert_false(staff.workable?('morning', "25 (6)"))
    assert_equal(staff.last_two_shift, ['morning', 'off'])
    assert_equal(staff.already_working_days, 0)
    staff.instance_eval do
      journey['1 (0)'] = 'morning'
    end
    assert_false(staff.workable?('afternoon', '1 (0)'))
    staff.instance_variable_set(:@already_working_days, 6)
    assert_false(staff.workable?('morning', "29 (6)"))
  end

  def test_afternoon_shift_priority
    staff = create_staff({ last_two_shift: ['afternoon', 'afternoon'], already_working_days: 3 })
    staff.afternoon_shift_priority
    assert_equal(4 + 3, staff.priority)

    staff.instance_variable_set(:@already_working_days, 2)
    staff.afternoon_shift_priority
    assert_equal(4 + 2, staff.priority)

    staff.instance_variable_set(:@last_two_shift, ['off', 'off'])
    staff.afternoon_shift_priority
    assert_equal(3, staff.priority)

    staff.instance_variable_set(:@last_two_shift, ['afternoon', 'off'])
    staff.afternoon_shift_priority
    assert_equal(2, staff.priority)

    staff.instance_variable_set(:@last_two_shift, ['morning', 'off'])
    staff.afternoon_shift_priority
    assert_equal(2, staff.priority)

    staff.instance_variable_set(:@last_two_shift, ['off', 'morning'])
    staff.afternoon_shift_priority
    assert_equal(1, staff.priority)
  end
  
  def test_morning_shift_priority
    staff = create_staff({ last_two_shift: ['morning', 'morning'], already_working_days: 3 })
    staff.morning_shift_priority
    assert_equal(3 + 3, staff.priority)

    staff.instance_variable_set(:@already_working_days, 2)
    staff.morning_shift_priority
    assert_equal(3 + 2, staff.priority)

    staff.instance_variable_set(:@last_two_shift, ['off', 'off'])
    staff.morning_shift_priority
    assert_equal(2, staff.priority)

    staff.instance_variable_set(:@last_two_shift, ['afternoon', 'off'])
    staff.morning_shift_priority
    assert_equal(1, staff.priority)

    staff.instance_variable_set(:@last_two_shift, ['morning', 'off'])
    staff.morning_shift_priority
    assert_equal(1, staff.priority)
  end

  def test_date_range
    staff = create_staff
    assert_equal('14 (1)', staff.date_range('12 (6)', 2))
    assert_equal('21 (1)', staff.date_range('20 (0)', 1))
    assert_equal('23 (3)', staff.date_range('1 (2)', 22))
  end

  def test_set_up_no_midnight
    staff = create_staff
    result = staff.set_up_no_midnight(back: -3, forecast: 3)
    assert_equal(["7", "8", "9", "10", "11", "12", "13", "17", "18", "19", "20", "21", "22", "23", "24", "25", "26", "27", "28"] , result)
  end

  def test_midnight_forecast
    staff = create_staff(last_two_shift: ['morning', 'morning'])
    staff.journey["3 (4)"] = 'midnight'
    result = staff.midnight_forecast('1 (2)')

  end

  def create_staff(args = {})
    staff_info = { name: 'Gary', req_off: ['10', '20' ,'25'], already_working_days: 0,
                   last_two_shift: ['off', 'off'] }
    
    Staff.new(staff_info.merge(args))
  end
end
