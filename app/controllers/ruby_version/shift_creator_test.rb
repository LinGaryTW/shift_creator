require "test/unit"
require 'mocha/test_unit'
require './shift_creator.rb'
require './staff.rb'

class ShiftCreatorTest < Test::Unit::TestCase
  def test_create_shift
    staff_info = { staff: [{ name: 'Gary', last_two_shift: ['morning', 'off'], already_working_days: 0 },
                           { name: 'David', last_two_shift: ['morning', 'morning'], already_working_days: 3 },
                           { name: 'Lucy', last_two_shift: ['off', 'morning'], already_working_days: 1 },
                           { name: 'Tina', last_two_shift: ['afternoon', 'afternoon'], already_working_days: 2 },
                           { name: 'Eric', last_two_shift: ['off', 'off'], already_working_days: 0 },
                           { name: 'Alice', last_two_shift: ['afternoon', 'afternoon'], already_working_days: 4 },
                           { name: 'Vicky', last_two_shift: ['midnight', 'midnight'], already_working_days: 2 }] }

    creator = create_shift_creator(staff_info)
    creator.create_shift
  end

  def test_check_params
    shift_creator = create_shift_creator
    
    assert_true(shift_creator.check_params)

    shift_creator = create_shift_creator(staff: [{ name: 'Gary'}, {name: 'David'}, { name: 'Lucy'}, { req_off: ['10'] }])
    assert_equal("missing name in staff no.4\n", shift_creator.check_params)

    shift_creator = create_shift_creator(weekday_hr: { morning: 2, afternoon: 2 })
    assert_equal("Missing shift config: midnight\n", shift_creator.check_params)

    shift_creator = create_shift_creator(month: nil)
    assert_equal("Missing Month config\n", shift_creator.check_params)
  end

  def test_parse_month
    result = create_shift_creator(month: 2).parse_month
    assert_equal(29, result.size)
    assert_equal("1 (6)", result.first)
    assert_equal("29 (6)", result.last)
  end

  def test_caculate_staff_human_resource
    creator = create_shift_creator
    result = creator.caculate_staff_human_resource
    assert_true(result[:hr] > 0)
    assert_equal(4, result[:hr])
    assert_equal('Sufficient!, please adjust manully', result[:message])

    creator.instance_variable_set(:@weekend_hr, { morning: 2, afternoon: 3, midnight: 1 })
    result = creator.caculate_staff_human_resource
    assert_true(result[:hr] < 0)
    assert_equal(-4, result[:hr])
    assert_equal('Understaffed, please arrange partime or recruit', result[:message])
  end

  def test_assign_first_midnight_shift
    staff_info = { staff: [{ name: 'Alice', last_two_shift: ['afternoon', 'afternoon'], already_working_days: 4 },
                           { name: 'Vicky', last_two_shift: ['midnight', 'midnight'], already_working_days: 2, midnight_count: 1 }] }
    creator = create_shift_creator(staff_info)
    assign_info = creator.assign_first_midnight_shift
    assert_equal(3, assign_info[:day])
    assert_equal('Vicky', assign_info[:name])
    creator.instance_eval do
      @staff.last.midnight_count = 0
    end
    assign_info = creator.assign_first_midnight_shift
    assert_equal(0, assign_info[:day])
    assert_nil(assign_info[:name])
  end

  def test_select_shift
    staff_info = { staff: [{ name: 'Gary', last_two_shift: ['morning', 'off'], already_working_days: 0, req_off: ['5', '6', '17'] },
                           { name: 'David', last_two_shift: ['morning', 'morning'], already_working_days: 3, req_off: ['12', '13', '22'] },
                           { name: 'Lucy', last_two_shift: ['off', 'morning'], already_working_days: 1, req_off: ['20', '26', '27'] },
                           { name: 'Tina', last_two_shift: ['afternoon', 'afternoon'], already_working_days: 2, req_off: ['6', '17', '18'] },
                           { name: 'Eric', last_two_shift: ['off', 'off'], already_working_days: 0, req_off: ['12', '13', '25'] },
                           { name: 'Alice', last_two_shift: ['afternoon', 'afternoon'], already_working_days: 4, req_off: ['16', '27', '28']},
                           { name: 'Vicky', last_two_shift: ['midnight', 'midnight'], already_working_days: 2, midnight_count: 1 }] }
    creator = create_shift_creator(staff_info)
    staff = creator.instance_variable_get(:@staff).select { |s| s.midnight_count <= 0 }
    stack = {}
    start_index = 0
    unassign_days = creator.parse_month[3..-1]
    result = creator.select_shift(staff, start_index, stack, unassign_days)
    assert_equal(creator.parse_month[3..-1], result.values.flatten.sort{ |a, b| a[/\d{1,2}/].to_i <=> b[/\d{1,2}/].to_i })
    assert_false(result.keys.include?('Vicky'))
    assert_equal(['Vicky'], staff_info[:staff].map{ |s| s[:name] } - result.keys)
    
    creator.instance_eval do
      eric = @staff.select { |s| s.name == 'Eric' }.first
      eric.no_midnight_range = eric.set_up_no_midnight(back: -4, forecast: 4)
    end
    staff = creator.instance_variable_get(:@staff).select { |s| s.midnight_count <= 0 }
    result = creator.select_shift(staff, start_index, stack, unassign_days)
    assert_false(result)
  end

  def test_arrange_midnight_shift
    staff_info = { staff: [{ name: 'Gary', last_two_shift: ['morning', 'off'], already_working_days: 0, req_off: ['5', '6', '17'] },
                           { name: 'David', last_two_shift: ['morning', 'morning'], already_working_days: 3, req_off: ['12', '13', '22'] },
                           { name: 'Lucy', last_two_shift: ['off', 'morning'], already_working_days: 1, req_off: ['20', '26', '27'] },
                           { name: 'Tina', last_two_shift: ['afternoon', 'afternoon'], already_working_days: 2, req_off: ['6', '17', '18'] },
                           { name: 'Eric', last_two_shift: ['off', 'off'], already_working_days: 0, req_off: ['12', '13', '25'] },
                           { name: 'Alice', last_two_shift: ['afternoon', 'afternoon'], already_working_days: 4, req_off: ['16', '27', '28']},
                           { name: 'Vicky', last_two_shift: ['midnight', 'midnight'], already_working_days: 2, midnight_count: 1 }] }
    creator = create_shift_creator(staff_info)
    creator.arrange_midnight_shift
    staff = creator.instance_variable_get(:@staff)
    staff.each do |s|
      assert_false(s.journey.empty?)
    end
    assert_true((creator.parse_month[3..-1] - staff.reduce([]) { |accu, s| accu + s.journey.keys }).empty?)
  end

  def test_compare_priority_and_arrange_staff
    creator = create_shift_creator({ weekday_hr: { 'morning': 2, 'afternoon': 2, 'midnight': 1 },
                                     weekend_hr: { 'morning': 2, 'afternoon': 2, 'midnight': 1 } })
    creator.instance_eval do
      @staff[0].priority = 3
      @staff[1].priority = 2
      @staff[2].priority = 1
    end
    creator.compare_priority_and_arrange_staff('morning', '18 (5)')
    
    staff1 = creator.instance_variable_get(:@staff)[0]
    staff3 = creator.instance_variable_get(:@staff)[2]
    assert_equal([["18 (5)", "morning"]], staff1.journey.to_a)
    assert_equal(['off', 'morning'], staff1.last_two_shift)
    assert_equal(1, staff1.already_working_days)
    assert_nil(staff3.journey['18 (5)'])
    assert_equal(['off', 'off'], staff3.last_two_shift)
    assert_equal(0, staff3.already_working_days)

    creator.instance_eval do
      @staff[0].priority = 1
      @staff[1].priority = 2
      @staff[2].priority = 3
    end

    creator.compare_priority_and_arrange_staff('afternoon', '19 (6)')
    staff1 = creator.instance_variable_get(:@staff)[0]
    staff2 = creator.instance_variable_get(:@staff)[1]
    staff3 = creator.instance_variable_get(:@staff)[2]
    assert_equal([["18 (5)", "morning"]], staff1.journey.to_a)
    assert_equal(['off', 'morning'], staff1.last_two_shift)
    assert_equal(1, staff1.already_working_days)
    assert_equal([["18 (5)", "morning"], ["19 (6)", 'afternoon']], staff2.journey.to_a)
    assert_equal(['morning', 'afternoon'], staff2.last_two_shift)
    assert_equal(2, staff2.already_working_days)
    assert_equal([["19 (6)", 'afternoon']], staff3.journey.to_a)
    assert_equal(['off', 'afternoon'], staff3.last_two_shift)
    assert_equal(1, staff3.already_working_days)
  end

  def test_let_remain_staff_off
    creator = create_shift_creator
    creator.instance_eval do
      @staff[0..1].each { |staff| staff.journey['19 (6)'] = 'morning' }
      @staff[0..1].each { |staff| staff.already_working_days = 1 }
      @staff[2..3].each { |staff| staff.journey['19 (6)'] = 'morning' }
      @staff[2..3].each { |staff| staff.already_working_days = 1 }
      @staff[4].journey['19 (6)'] = 'midnight'
      @staff[4].already_working_days = 1
      @staff[5].already_working_days = 3
      @staff[6].already_working_days = 3
    end
    creator.let_remain_staff_off('19 (6)')
    staff1 = creator.instance_variable_get(:@staff)[-1]
    staff2 = creator.instance_variable_get(:@staff)[-2]
    staff3 = creator.instance_variable_get(:@staff)[-3]
    assert_equal('off', staff1.journey['19 (6)'])
    assert_equal('off', staff2.journey['19 (6)'])
    assert_equal('midnight', staff3.journey['19 (6)'])
    assert_equal(0, staff1.already_working_days)
    assert_equal(0, staff2.already_working_days)
    assert_equal(1, staff3.already_working_days)
  end

  def test_arrange_shift
    #                  last 2 day           date
    #                            |1   2   3   4   5   6   7
    #staff  already work                expect shift
    #  1         0       7   off |off 7   7   7   7   off 14  
    #  2         3       7   7   |7   off 14  14  14  14  off 
    #  3         1       off 7   |7   7   7   off off 7   7 
    #  4         2       14  14  |14  14  off 7   7   7   7 
    #  5         0       off off |14  14  14  14  off off 23  
    #  6         4       14  14  |off off 23  23  23  23  off 
    #  7         2       23  23  |23  23  off off 14  14  14  

    staff_info = { staff: [{ name: 'Gary', last_two_shift: ['morning', 'off'], already_working_days: 0 },
                           { name: 'David', last_two_shift: ['morning', 'morning'], already_working_days: 3 },
                           { name: 'Lucy', last_two_shift: ['off', 'morning'], already_working_days: 1 },
                           { name: 'Tina', last_two_shift: ['afternoon', 'afternoon'], already_working_days: 2 },
                           { name: 'Eric', last_two_shift: ['off', 'off'], already_working_days: 0 },
                           { name: 'Alice', last_two_shift: ['afternoon', 'afternoon'], already_working_days: 4 },
                           { name: 'Vicky', last_two_shift: ['midnight', 'midnight'], already_working_days: 2 }] }

    creator = create_shift_creator(staff_info)
    creator.stubs(:parse_month).returns(['1 (1)', '2 (2)', '3 (3)', '4 (4)', '5 (5)', '6 (6)', '7  0)'])
    creator.arrange_shift
    all_staff = creator.instance_variable_get(:@staff)
    
    assert_equal(['off', 'morning', 'morning', 'morning', 'morning', 'off', 'afternoon'],all_staff[0].journey.values)
    assert_equal(['morning', 'off', 'afternoon', 'afternoon', 'afternoon', 'afternoon', 'off'],all_staff[1].journey.values)
    assert_equal(['morning', 'morning', 'morning', 'off', 'off', 'morning', 'morning',],all_staff[2].journey.values)
    assert_equal(['afternoon', 'afternoon', 'off', 'morning', 'morning', 'morning', 'morning'],all_staff[3].journey.values)
    assert_equal(['afternoon', 'afternoon', 'afternoon', 'afternoon', 'off', 'off', 'midnight'],all_staff[4].journey.values)
    assert_equal(['off', 'off', 'midnight', 'midnight', 'midnight', 'midnight', 'off'],all_staff[5].journey.values)
    assert_equal(['midnight','midnight', 'off', 'off', 'afternoon', 'afternoon', 'afternoon'],all_staff[6].journey.values)
  end

  def create_shift_creator(args = {})
    default = { staff: [{ name: 'Gary', req_off: ['10', '20' ,'25'], pay_leave: ['24'] },
                       { name: 'David', req_off: ['10', '20' ,'25'], pay_leave: [] },
                       { name: 'Lucy', req_off: ['10', '20' ,'25'], pay_leave: [] },
                       { name: 'Tina', req_off: ['10', '20' ,'25'], pay_leave: [] },
                       { name: 'Eric', req_off: ['10', '20' ,'25'], pay_leave: [] },
                       { name: 'Alice', req_off: ['10', '20' ,'25'], pay_leave: ['31'] },
                       { name: 'Vicky', req_off: ['10', '20' ,'25'], pay_leave: [] }],
                weekday_hr: { 'morning': 2, 'afternoon': 2, 'midnight': 1 },
                weekend_hr: { 'morning': 2, 'afternoon': 2, 'midnight': 1 },
                month: 12 }

    ShiftCreator.new(default.merge(args))
  end
end
