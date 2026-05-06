class AddProfileFieldsToJobSeekerProfiles < ActiveRecord::Migration[8.1]
  def change
    add_column :job_seeker_profiles, :work_history, :text
    add_column :job_seeker_profiles, :education, :text
  end
end
