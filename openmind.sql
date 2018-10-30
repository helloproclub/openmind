/*!
 * Open Mind SQL
 * GGWP PostgreSQL
*/

CREATE TABLE participant(
  participant_id SERIAL PRIMARY KEY,
  participant_username VARCHAR (255) UNIQUE NOT NULL,
  participant_email VARCHAR (255) NOT NULL,
  checked_in BOOLEAN NOT NULL DEFAULT false,
  checked_at TIMESTAMP NULL,
  created_at TIMESTAMP NOT NULL
);

CREATE INDEX participant_username_index ON participant (participant_username);

CREATE TABLE waiting_list(
  waiting_list_id SERIAL PRIMARY KEY,
  waiting_list_username VARCHAR (255) UNIQUE NOT NULL,
  waiting_list_email VARCHAR (255) NOT NULL,
  created_at TIMESTAMP NOT NULL
);

CREATE INDEX waiting_list_index ON waiting_list (waiting_list_username);

