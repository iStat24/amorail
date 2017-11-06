require "spec_helper"

describe Amorail::User do
  before { mock_api }

  describe "validations" do
    it { should validate_presence_of(:name) }
  end

  describe ".attributes" do
    subject { described_class.attributes }

    it_behaves_like 'entity_class'

    specify do
      is_expected.to include(
                         :name,
                         :login,
                         :last_name,
                         :id
                     )
    end
  end

  describe "#params" do
    let(:user) do
      described_class.new(
          name: 'Mars',
          login: 'test@mail.com',
          last_name: 'Mars is best',
          id: 123
      )
    end

    subject { user.params }

    specify { is_expected.to include(:last_modified) }
    specify { is_expected.to include(name: 'Mars') }
    specify { is_expected.to include(login: 'test@mail.com') }
    specify { is_expected.to include(last_name: 'Mars is best') }
    specify { is_expected.to include(id: 123) }
  end
end
