class CreateJobApplications < ActiveRecord::Migration[8.1]
  def change
    create_table :job_applications, id: :uuid do |t|
      t.references :user, null: false, foreign_key: true, type: :uuid
      t.string :job_title, null: false
      t.string :company, null: false
      t.string :status, null: false, default: "applied"
      t.text :job_description
      t.string :url
      t.text :notes
      t.date :applied_on
      t.timestamps null: false
    end

    add_index :job_applications, [:user_id, :created_at]
    add_index :job_applications, :status
  end
end
