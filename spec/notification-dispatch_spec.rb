require 'spec_helper'

describe Notification do
  describe Notification::Dispatch do
    let(:map_hash)   { {
                          :datadog => {:api_key => 'DATADOG_API_KEY'},
                          :keen    => {
                            :project_id => 'KEEN_PROJECT_ID',
                            :master_key => 'KEEN_MASTER_KEY',
                            :write_key  => 'KEEN_WRITE_KEY',
                            :read_key   => 'KEEN_READ_KEY'
                          }
                        } 
                     }
    let(:key_values) { {
                          :datadog => {:api_key => 'datadog_api_key_val'},
                          :keen    => {
                            :project_id => 'keen_project_id',
                            :master_key => 'keen_master_key',
                            :write_key  => 'keen_write_key',
                            :read_key   => 'keen_read_key'
                          }
                       } 
                     }

    def clear_environment
      map_hash.values.each {|key_hash| key_hash.each_value {|val| allow(ENV).to receive(:[]).with(val).and_return("") }}
    end

    def enable_aws
      allow(ENV).to receive(:[]).with(map_hash[:aws][:access_key]).and_return(key_values[:aws][:access_key])
      allow(ENV).to receive(:[]).with(map_hash[:aws][:secret_key]).and_return(key_values[:aws][:secret_key])
    end

    def enable_datadog
      allow(ENV).to receive(:[]).with(map_hash[:datadog][:api_key]).and_return(key_values[:datadog][:api_key])
      allow(ENV).to receive(:[]).with("DATADOG_HOST").and_return('localhost')
    end

    def enable_keen
      allow(ENV).to receive(:[]).with(map_hash[:keen][:project_id]).and_return(key_values[:keen][:project_id])
      allow(ENV).to receive(:[]).with(map_hash[:keen][:master_key]).and_return(key_values[:keen][:master_key])
      allow(ENV).to receive(:[]).with(map_hash[:keen][:write_key]).and_return(key_values[:keen][:write_key])
      allow(ENV).to receive(:[]).with(map_hash[:keen][:read_key]).and_return(key_values[:keen][:read_key])
    end

    describe Notification::Dispatch::Client do
      let(:client) { Notification::Dispatch::Client.new }

      before(:each) { clear_environment }

      specify { expect(Notification::Dispatch::Client::KEY_MAPS).to eql(map_hash) }

      describe "#initialize" do

        specify { expect(client.key_map).to be_empty }
        specify { expect(client.msg_classes).to be_empty }
        specify { expect(client.is_active?).to be false }

        subject { client.clients }

        context "when no clients are configured" do
          it { expect(subject).to be_empty }
        end

        context "when Datadog client is active" do
          before(:each) { enable_datadog }

          it { expect(subject).to_not be_empty }
        end
      end

      describe "#has_active_clients?" do

        subject { client.has_active_clients? }

        context "when no clients are configured" do
          it { expect(subject).to be false }
        end

        context "when a client is configured" do
          before(:each) { enable_datadog }

          it { expect(subject).to be true }
        end
      end

      describe "#handle_message?" do
        specify { expect(client.handle_message?(:event, :info)).to be false }
      end

      describe "#message" do
        let(:msg_subject) { "notification subject" }
        let(:msg)         { "notification message" }
        let(:opts)        { {} }
        let(:msg_classes) { {:event => [:error, :warning, :info, :success]} }
        let(:msg_class) { :event }
        let(:msg_type)  { msg_classes[:event].first }

        subject { client.message(msg_class, msg_type, msg_subject, msg, opts) }

        context "with no active clients" do
          it { expect(subject).to eql(0) }
        end

        context "with active datadog client" do
          before(:each) do
            enable_datadog
            allow(Dogapi::Client).to receive_message_chain(:new, :emit_event) { true }
            allow(Dogapi::Event).to receive(:new).and_return(true)
          end

          it { expect(subject).to eql(1) }
        end
      end

    end

    describe Notification::Dispatch::Datadog do
      let(:client) { Notification::Dispatch::Datadog.new }
      let(:msg_classes) { {:event => [:error, :warning, :info, :success]} }

      before(:each) do
        clear_environment
      end

      describe "#initialize" do
        
        specify { expect(client.key_map).to eql(map_hash[:datadog]) }
        specify { expect(client.msg_classes).to eql(msg_classes) }

        context "when not active" do
          specify { expect(client.conn).to be_nil }
        end

        context "when active" do
          before(:each) { enable_datadog }

          specify { expect(client.conn).to_not be_nil }
          specify { expect(client.key).to eql(key_values[:datadog][:api_key]) }
        end
      end

      describe "#is_active?" do

        subject { client.is_active? }

        context "when required env var is set" do
          before(:each) { enable_datadog }

          it { should be true }
        end

        context "when required env var is not set" do
          it { should be false }
        end
      end

      describe "#connect" do
        before(:each) do
          enable_datadog
          allow(Dogapi::Client).to receive(:new).and_return(true)
        end

        specify { expect(client.connect).to be true }        
      end

      describe "#handle_message?" do

        subject { client.handle_message?(msg_class, msg_type) }

        context "with unknown msg_class" do
          let(:msg_class) { :unknown }

          context "and unknown msg_type" do
            let(:msg_type) { :unknown }
            it { should be false }
          end

          context "and known msg_type" do
            let(:msg_type) { msg_classes[:event].first }
            it { should be false }
          end
        end

        context "with known msg_class" do
          let(:msg_class) { :event }

          context "and unknown msg_type" do
            let(:msg_type) { :unknown }
            it { should be false }
          end

          context "and known msg_type" do
            let(:msg_type) { msg_classes[:event].first }
            it { should be true }
          end
        end
      end

      describe "#message" do
        let(:msg_subject) { "notification subject" }
        let(:msg)         { "notification message" }
        let(:opts)        { {} }

        before(:each) do
          enable_datadog
          allow(Dogapi::Client).to receive_message_chain(:new, :emit_event) { true }
          allow(Dogapi::Event).to receive(:new).and_return(true)
        end

        subject { client.message(msg_class, msg_type, msg_subject, msg, opts) }

        context "when unable to handle_message" do
          let(:msg_class) { :unknown }
          let(:msg_type)  { :unknown }

          it "should raise an error" do 
            expect(lambda { client.message(msg_class, msg_type, msg_subject, msg, opts) }).to raise_error
          end
        end

        context "when able to handle_message" do
          let(:msg_class) { :event }
          let(:msg_type)  { msg_classes[:event].first }

          it { should be true }
        end
      end
    end

    describe Notification::Dispatch::Keen do
      let(:client) { Notification::Dispatch::Keen.new }
      let(:msg_classes) { {:metric => [:counter, :gauge]} }

      before(:each) { clear_environment }

      describe "#initialize" do
        
        specify { expect(client.key_map).to eql(map_hash[:keen]) }
        specify { expect(client.msg_classes).to eql(msg_classes) }

        context "when not active" do
          specify { expect(client.conn).to be_nil }
        end

        context "when active" do
          before(:each) { enable_keen }

          specify { expect(client.conn).to_not be_nil }
        end
      end

      describe "#is_active?" do

        subject { client.is_active? }

        context "when required env vars are set" do
          before(:each) { enable_keen }

          it { should be true }
        end

        context "when required env vars are not set" do
          it { should be false }
        end
      end

      describe "#message" do
        let(:msg_subject) { "" }
        let(:msg)         { "notification message" }
        let(:opts)        { {} }

        before(:each) { enable_keen }

        subject { client.message(msg_class, msg_type, msg_subject, msg, opts) }

        context "when unable to handle_message" do
          let(:msg_class) { :unknown }
          let(:msg_type)  { :unknown }

          it "should raise an error" do 
            expect(lambda { client.message(msg_class, msg_type, msg_subject, msg, opts) }).to raise_error
          end
        end

        context "when able to handle_message" do
          let(:msg_class) { :metric }
          let(:msg_type)  { msg_classes[:metric].first }
          let(:data) { { :some => :hash } }
          let(:message_data) { {
              :collection => "test_collection",
              :data => data
            }
          }
          let(:opts) { message_data }

          before(:each) { allow(Keen).to receive(:publish).with(message_data[:collection], message_data[:data]).and_return(true) }

          context "and missing collection option" do
            let(:message_data) { {:data => {:some => :hash} } }

            it "should raise an exception" do
              expect(lambda { client.message(msg_class, msg_type, msg_subject, msg, opts) }).to raise_error
            end
          end

          context "and missing data option" do
            let(:message_data) { {:collection => :some_collection } }

            it "should raise an exception" do
              expect(lambda { client.message(msg_class, msg_type, msg_subject, msg, opts) }).to raise_error
            end
          end

          context "and both collection and data options are specified" do
            context "and data option is an array" do
              let(:data) { [{:array => :hash}] }
              before(:each) { expect(Keen).to receive(:publish_batch).with(message_data[:collection], message_data[:data]).and_return(true) }

              it { should be true }
            end

            context "and data option is not an array" do
              it { should be true }
            end
          end
        end
      end
    end
  end
end