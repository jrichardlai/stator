require 'spec_helper'

describe Stator::Model do

  it 'should set the default state after initialization' do
    u = User.new
    u.state.should eql('pending')
  end

  it 'should see the initial setting of the state as a change with the initial state as the previous value' do
    u = User.new
    u.state = 'activated'
    u.state_was.should eql('pending')
  end

  it 'should not obstruct normal validations' do
    u = User.new
    u.should_not be_valid
    u.errors[:email].grep(/length/).should_not be_empty
  end

  it 'should ensure a valid state transition when given a bogus state' do
    u = User.new
    u.state = 'anythingelse'

    u.should_not be_valid
    u.errors[:state].should eql(['is not a valid state'])
  end

  it 'should allow creation at any state' do
    u = User.new(:email => 'doug@example.com')
    u.state = 'hyperactivated'

    u.should be_valid
  end

  it 'should ensure a valid state transition when given an illegal state based on the current state' do
    u = User.new
    u.stub(:new_record?).and_return(false)
    u.state = 'hyperactivated'

    u.should_not be_valid
    u.errors[:state].should_not be_empty
  end

  it 'should not allow a transition that is currently in a `to` state' do
    u = User.new(:email => 'fred@example.com')
    u.activate!
    u.hyperactivate!

    lambda{
      u.hyperactivate!
    }.should raise_error(/cannot transition to \"hyperactivated\" from \"hyperactivated\"/)
  end

  it 'should run conditional validations' do
    u = User.new
    u.state = 'semiactivated'
    u.should_not be_valid

    u.errors[:state].should be_empty
    u.errors[:email].grep(/format/).should_not be_empty
  end

  it 'should invoke callbacks' do
    u = User.new(:activated => true, :email => 'doug@example.com', :name => 'doug')
    u.activated.should == true

    u.deactivate

    u.activated.should == false
    u.state.should eql('deactivated')
    u.activated_state_at.should be_nil
    u.should be_persisted
  end

  it 'should blow up if the record is invalid and a bang method is used' do
    u = User.new(:email => 'doug@other.com', :name => 'doug')
    lambda{
      u.activate!
    }.should raise_error(ActiveRecord::RecordInvalid)
  end

  it 'should allow for other fields to be used other than state' do
    a = Animal.new
    a.should be_valid

    a.birth!
  end

  it 'should create implicit transitions for state declarations' do
    a = Animal.new
    a.should_not be_grown_up
    a.status = 'grown_up'
    a.save
  end

  it 'should allow multiple machines in the same model' do
    f = Farm.new
    f.should be_dirty
    f.should be_house_dirty

    f.cleanup

    f.should_not be_dirty
    f.should be_house_dirty

    f.house_cleanup

    f.should_not be_house_dirty
  end

  it 'should allow saving to be skipped' do
    f = Farm.new
    f.cleanup(false)

    f.should_not be_persisted
  end

  it 'should allow no initial state' do
    f = Factory.new
    f.state.should be_nil

    f.construct.should be_true

    f.state.should eql('constructed')
  end

  describe 'helper methods' do

    it 'should answer the question of whether the state is currently the one invoked' do
      a = Animal.new
      a.should be_unborn
      a.should_not be_born

      a.birth

      a.should be_born
      a.should_not be_unborn
    end

    it 'should determine if it can validly execute a transition' do
      a = Animal.new
      a.can_birth?.should be_true

      a.birth

      a.can_birth?.should be_false
    end

  end

  describe 'tracker methods' do

    before do
      Time.zone = 'Eastern Time (US & Canada)'
    end

    it 'should store when a record changed state for the first time' do
      a = Animal.new
      a.unborn_status_at.should be_nil
      a.born_status_at.should be_nil
      a.birth
      a.unborn_status_at.should be_within(1).of(Time.zone.now)
      a.born_status_at.should be_within(1).of(Time.zone.now)
    end

  end

  describe 'aliasing' do
    it 'should allow aliasing within the dsl' do
      u = User.new(:email => 'doug@example.com')
      u.should respond_to(:active?)
      u.should respond_to(:inactive?)

      u.should_not be_active

      u.inactive?
      u.should be_inactive

      u.activate!
      u.should be_active
      u.should_not be_inactive

      u.hyperactivate!
      u.should be_active
      u.should_not be_inactive

      User::ACTIVE_STATES.should eql(['activated', 'hyperactivated'])
      User::INACTIVE_STATES.should eql(['pending', 'deactivated', 'semiactivated'])

      u2 = User.create(:email => 'phil@example.com')

      User.active.to_sql.gsub('  ', ' ').should eq("SELECT users.* FROM users WHERE users.state IN ('activated', 'hyperactivated')")
      User.inactive.to_sql.gsub('  ', ' ').should eq("SELECT users.* FROM users WHERE users.state IN ('pending', 'deactivated', 'semiactivated')")
    end

    it 'should namespace aliases just like everything else' do
      f = Farm.new
      f.should respond_to(:house_cleaned?)

      f.should_not be_house_cleaned
      f.house_cleanup!

      f.should be_house_cleaned
    end

    it 'should allow for explicit constant and scope names to be provided' do
      User.should respond_to(:luke_warmers)
      defined?(User::LUKE_WARMERS).should be_true
      u = User.new
      u.should respond_to(:luke_warm?)
    end

    it 'should not create constants or scopes by default' do
      u = User.new
      u.should respond_to(:iced_tea?)
      defined?(User::ICED_TEA_STATES).should be_false
      User.should_not respond_to(:iced_tea)
    end
  end

end
