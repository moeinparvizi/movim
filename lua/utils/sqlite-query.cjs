const fs = require('node:fs');
try {
  const { DatabaseSync } = require('node:sqlite');
  const db = new DatabaseSync(process.argv[2]);
  try {
    const sql = fs.readFileSync(0, 'utf8').trim();
    const statement = db.prepare(sql);
    if (sql.slice(statement.sourceSQL.length).trim()) throw Error('Run one SQLite statement at a time.');
    statement.setReadBigInts(true);
    const columns = statement.columns();
    if (columns.length) {
      statement.setReturnArrays(true);
      console.log(columns.map(column => column.name).join('\t'));
      let count = 0;
      for (const row of statement.iterate()) {
        if (++count > 1000) { console.log('Showing first 1000 rows'); break; }
        console.log(row.map(value => value === null ? 'NULL' : String(value)).join('\t'));
      }
    } else {
      console.log('OK · changes: ' + statement.run().changes);
    }
  } finally { db.close(); }
} catch (error) {
  console.error(error.message);
  process.exitCode = 1;
}
