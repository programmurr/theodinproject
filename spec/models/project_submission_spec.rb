require 'rails_helper'

RSpec.describe ProjectSubmission, type: :model do
  subject { create(:project_submission) }

  it { is_expected.to belong_to(:user) }
  it { is_expected.to belong_to(:lesson) }
  it { is_expected.to have_many(:flags) }

  it { is_expected.to validate_presence_of(:repo_url).with_message('Required') }
  it { is_expected.to allow_value('http://www.github.com/fff').for(:repo_url) }
  it { is_expected.to allow_value('https://www.github.com/fff').for(:repo_url) }
  it { is_expected.to_not allow_value('not_a_url').for(:repo_url) }

  it { is_expected.to allow_value('http://www.github.com/fff').for(:live_preview_url) }
  it { is_expected.to allow_value('https://www.github.com/fff').for(:live_preview_url) }
  it { is_expected.to_not allow_value('not_a_url').for(:live_preview_url) }

  it { is_expected.to validate_uniqueness_of(:user_id).scoped_to(:lesson_id) }

  describe '.only_public' do
    it 'returns public project submissions' do
      public_project_submission_one = create(:project_submission)
      public_project_submission_two = create(:project_submission)
      create(:project_submission, is_public: false)

      expect(ProjectSubmission.only_public).to contain_exactly(
        public_project_submission_one,
        public_project_submission_two
      )
    end
  end

  describe '.not_removed_by_admin' do
    it 'returns project submissions that have not been discarded' do
      not_discarded_project_submission = create(:project_submission)
      create(:project_submission, discarded_at: Time.zone.today)
      create(:project_submission, discarded_at: Time.zone.today)

      expect(ProjectSubmission.not_removed_by_admin).to contain_exactly(
        not_discarded_project_submission
      )
    end
  end

  describe '.created_today' do
    let!(:project_submission_created_today) do
      create(:project_submission, created_at: Time.zone.today)
    end

    let!(:project_submission_not_not_created_today) do
      create(:project_submission, created_at: Time.zone.today - 2.days)
    end

    it 'returns projects submission created today' do
      expect(ProjectSubmission.created_today).to contain_exactly(project_submission_created_today)
    end
  end

  describe '.discardable' do
    context 'when the project submission discard_at date is in the past' do
      let(:project_submission) { create(:project_submission, discard_at: 8.days.ago) }

      it 'returns a list including the project submission' do
        expect(described_class.discardable).to include(project_submission)
      end
    end

    context 'when the project submission discard_at date is in the future' do
      let(:project_submission) { create(:project_submission, discard_at: 1.day.from_now) }

      it 'returns a list not including the project submission' do
        expect(described_class.discardable).not_to include(project_submission)
      end
    end

    context 'when the project submission discard_at date is today' do
      let(:project_submission) { create(:project_submission, discard_at: 5.minutes.ago) }

      it 'returns a list including the project submission' do
        expect(described_class.discardable).to include(project_submission)
      end
    end

    context 'when the project submission discard_at date is nil' do
      let(:project_submission) { create(:project_submission, discard_at: nil) }

      it 'returns a list not including the project submission' do
        expect(described_class.discardable).not_to include(project_submission)
      end
    end

    context 'when the project_submission has been removed by admin' do
      let(:project_submission) do
        create(:project_submission, discarded_at: 10.days.ago, discard_at: 6.days.ago)
      end

      it 'returns a list not including the project submission' do
        expect(described_class.discardable).not_to include(project_submission)
      end
    end
  end

  describe '.before_update callback' do
    let(:discardable_project_submission) { create(:project_submission, discard_at: discard_date) }
    let(:discard_date) { DateTime.new(2021, 9, 1) }

    context 'when the repo url is being updated' do
      let(:repo_url) { 'https://www.legitrepo.com' }

      it 'sets discard_at to nil' do
        discardable_project_submission.update(repo_url: repo_url)

        expect(discardable_project_submission.reload.discard_at).to be_nil
      end
    end

    context 'when the live_preview_url is being updated' do
      let(:live_preview_url) { 'https://legitlivepreview.com' }

      it 'sets discard_at to nil' do
        discardable_project_submission.update(live_preview_url: live_preview_url)

        expect(discardable_project_submission.reload.discard_at).to be_nil
      end
    end

    context 'when any other attribute is updated' do
      it 'does not modify update at' do
        discardable_project_submission.update(is_public: false)

        expect(discardable_project_submission.reload.discard_at).to eq(discard_date)
      end
    end
  end
end
