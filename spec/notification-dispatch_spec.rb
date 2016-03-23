require 'spec_helper'

describe Notification do
  describe Notification::Dispatch do
    let(:map_hash)   { {#:aws => {:access_key => 'AWS_ACCESS_KEY', :secret_key => 'AWS_SECRET_KEY'},
                        :datadog => {:api_key => 'DATADOG_API_KEY'}} }
    let(:key_values) { {#:aws => {:access_key => 'aws_access_key_val', :secret_key => 'aws_secret_key_val'},
                        :datadog => {:api_key => 'datadog_api_key_val'}} }

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

        pending "when AWS client is active" do
          before(:each) { enable_aws }

          it { expect(subject).to_not be_empty }
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

    #
    # AWS Client
    #
    pending "Notification::Dispatch::Aws" do
      let(:client) { Notification::Dispatch::Aws.new }

      before(:each) do
        clear_environment
      end

      describe "#initialize" do
        specify { client.key_map.should eql(map_hash[:aws]) }
      end

      describe "#is_active?" do

        subject { client.is_active? }

        context "when both required env vars are set" do
          before(:each) do
            enable_aws
          end

          it { should be_true }
        end

        context "when only one of the required env vars is set" do
          before(:each) do
            ENV.stub(:[]).with(client.key_map.values[0]).and_return("")
            ENV.stub(:[]).with(client.key_map.values[1]).and_return("secret")
          end

          it { should be_false }
        end

        context "when neither of the required env vars is set" do
          it { should be_false }
        end
      end
    end

    #
    # Datadog Client
    #
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
  end
end