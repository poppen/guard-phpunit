require 'spec_helper'

describe Guard::PHPUnit do

  let(:runner)    { Guard::PHPUnit::Runner }
  let(:inspector) { Guard::PHPUnit::Inspector }
  let(:defaults)  { Guard::PHPUnit::DEFAULT_OPTIONS }

  describe '#initialize' do
    context 'when no options are provided' do
      it 'sets a default :all_on_start option' do
        subject.options[:all_on_start].should be_true
      end

      it 'sets a default :all_after_pass option' do
        subject.options[:all_after_pass].should be_true
      end

      it 'sets a default :keep_failed option' do
        subject.options[:keep_failed].should be_true
      end

      it 'sets a default :tests_path option' do
        subject.options[:tests_path].should == @project_path.to_s
      end

      it 'sets a default :command option' do
        subject.options[:command].should == 'phpunit'
      end
    end

    context 'when other options are provided' do

      subject { Guard::PHPUnit.new(nil, { :all_on_start   => false,
                                          :all_after_pass => false,
                                          :keep_failed    => false,
                                          :cli            => '--colors',
                                          :tests_path     => 'tests',
                                          :command        => './bin/phpunit' }) }

      it 'sets :all_on_start with the provided option' do
        subject.options[:all_on_start].should be_false
      end

      it 'sets :all_after_pass with the provided option' do
        subject.options[:all_after_pass].should be_false
      end

      it 'sets :keep_failed with the provided option' do
        subject.options[:keep_failed].should be_false
      end

      it 'sets :cli with the provided option' do
        subject.options[:cli].should == '--colors'
      end

      it 'sets :tests_path with the provided option' do
        subject.options[:tests_path].should == 'tests'
      end

      it 'sets :command the provided option' do
        subject.options[:command].should == './bin/phpunit'
      end
    end

    it 'sets the tests path for the inspector' do
      inspector.should_receive(:tests_path=).with(@project_path.to_s)
      subject
    end
  end

  # ----------------------------------------------------------

  describe '#start' do
    it 'calls #run_all' do
      subject.should_receive(:run_all)
      subject.start
    end

    context 'with the :all_on_start option set to false' do
      subject { Guard::PHPUnit.new(nil, :all_on_start => false) }

      it 'calls #run_all' do
        subject.should_not_receive(:run_all)
        subject.start
      end
    end
  end

  describe '#run_all' do
    it 'runs all tests in the tests path' do
      runner.should_receive(:run).with(defaults[:tests_path], anything).and_return(true)
      subject.run_all
    end

    it 'throws :task_has_failed when an error occurs' do
      runner.should_receive(:run).with(defaults[:tests_path], anything).and_return(false)
      expect { subject.run_all }.to throw_symbol :task_has_failed
    end

    it 'passes the options to the runner' do
      runner.should_receive(:run).with(anything, hash_including(defaults)).and_return(true)
      subject.run_all
    end
  end

  describe '#run_on_changes' do
    before do
      inspector.stub(:clean).and_return { |paths| paths }
    end

    it 'cleans the changed paths before running the tests' do
      runner.stub(:run).and_return(true)
      inspector.should_receive(:clean).with(['tests/firstTest.php', 'tests/secondTest.php'])
      subject.run_on_changes ['tests/firstTest.php', 'tests/secondTest.php']
    end

    it 'runs the changed tests' do
      runner.should_receive(:run).with(['tests/firstTest.php', 'tests/secondTest.php'], anything).and_return(true)
      subject.run_on_changes ['tests/firstTest.php', 'tests/secondTest.php']
    end

    it 'throws :task_has_failed when an error occurs' do
      runner.should_receive(:run).with(['tests/firstTest.php', 'tests/secondTest.php'], anything).and_return(false)
      expect { subject.run_on_changes ['tests/firstTest.php', 'tests/secondTest.php'] }.to throw_symbol :task_has_failed
    end

    it 'passes the options to the runner' do
      runner.should_receive(:run).with(anything, hash_including(defaults)).and_return(true)
      subject.run_on_changes ['tests/firstTest.php', 'tests/secondTest.php']
    end

    context 'when tests fail' do
      before do
        runner.stub(:run).and_return(false)
        subject.stub(:run_all).and_return(true)
      end

      context 'with the :keep_failed option set to true' do
        it 'runs the next changed files plus the failed tests' do
          expect { subject.run_on_changes ['tests/firstTest.php'] }.to throw_symbol :task_has_failed
          runner.should_receive(:run).with(
            ['tests/secondTest.php', 'tests/firstTest.php'], anything
          ).and_return(true)

          subject.run_on_changes ['tests/secondTest.php']
        end
      end

      context 'with the :keep_failed option set to false' do
        subject { Guard::PHPUnit.new(nil, :keep_failed => false) }

        it 'runs the next changed files normally without the failed tests' do
          expect { subject.run_on_changes ['tests/firstTest.php'] }.to throw_symbol :task_has_failed
          runner.should_receive(:run).with(
            ['tests/secondTest.php'], anything
          ).and_return(true)

          subject.run_on_changes ['tests/secondTest.php']
        end
      end
    end

    context 'when tests fail then pass' do
      before do
        runner.stub(:run).and_return(false, true)
      end

      context 'with the :all_after_pass option set to true' do
        it 'calls #run_all' do
          subject.should_receive(:run_all)
          expect { subject.run_on_changes ['tests/firstTest.php'] }.to throw_symbol :task_has_failed
          subject.run_on_changes ['tests/firstTest.php']
        end

        it 'calls #run_all (2)' do
          expect { subject.run_all }.to throw_symbol :task_has_failed
          subject.should_receive(:run_all)
          subject.run_on_changes ['tests/firstTest.php']
        end
      end

      context 'with the :all_after_pass option set to false' do
        subject { Guard::PHPUnit.new(nil, :all_after_pass => false) }

        it 'does not call #run_all' do
          subject.should_not_receive(:run_all)
          expect { subject.run_on_changes ['tests/firstTest.php'] }.to throw_symbol :task_has_failed
          subject.run_on_changes ['tests/firstTest.php']
        end

        it 'does not call #run_all (2)' do
          expect { subject.run_all }.to throw_symbol :task_has_failed
          subject.should_not_receive(:run_all)
          subject.run_on_changes ['tests/firstTest.php']
        end
      end
    end
  end
end
