class CreateJobSeekerProfiles < ActiveRecord::Migration[8.1]
  def change
    create_table :job_seeker_profiles, id: :uuid do |t|
      t.references :user, null: false, foreign_key: true, type: :uuid, index: false
      t.text :background_summary, null: false, default: ""
      t.text :key_skills, null: false, default: ""
      t.timestamps null: false
    end

    add_index :job_seeker_profiles, :user_id, unique: true
  end
end
