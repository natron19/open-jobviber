class CreateCoverLetters < ActiveRecord::Migration[8.1]
  def change
    create_table :cover_letters, id: :uuid do |t|
      t.references :job_application, null: false, foreign_key: true, type: :uuid
      t.string :tone, null: false
      t.text :body, null: false
      t.text :gemini_raw
      t.timestamps null: false
    end

    add_index :cover_letters, [:job_application_id, :created_at]
  end
end
