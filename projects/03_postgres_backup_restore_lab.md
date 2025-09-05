# Project 3: PostgreSQL Backup & Restore Lab

Goal: Practice reliable logical backups and restores.

## Steps
1) Install Postgres
- Debian: `sudo apt install -y postgresql`

2) Create sample DB
```
sudo -u postgres psql -c "CREATE DATABASE demo;"
sudo -u postgres psql -d demo -c "CREATE TABLE items(id serial primary key, name text);"
sudo -u postgres psql -d demo -c "INSERT INTO items(name) VALUES ('alpha'),('beta');"
```

3) Backup
```
sudo -u postgres pg_dump -Fc demo > /backups/demo_$(date +%F).dump
```

4) Restore test
```
sudo -u postgres dropdb demo
sudo -u postgres createdb demo
sudo -u postgres pg_restore -d demo /backups/demo_$(date +%F).dump
sudo -u postgres psql -d demo -c "SELECT * FROM items;"
```

5) Automate (cron/systemd timer)
- Create a script under `/usr/local/bin/pg_backup.sh` that writes to `/backups/` and rotates by date.

Outcome: You can take and verify Postgres backups confidently.
