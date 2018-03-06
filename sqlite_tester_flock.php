<?php

/**
 * PHP Version 7.1
 *
 * Do a bunch of sqlite things.
 */

$path = '/mnt/testfile.db';
$lock_path = '/mnt/testfile.db.lock';

$options = getopt("fi:n:");
$use_file_lock = array_key_exists('f', $options);
$which_test = array_key_exists('i', $options) ? $options['i'] : 0;
$count = array_key_exists('n', $options) ? $options['n'] : 10000;
$key_cache = [];

$db = new SQLite3($path);
$db->busyTimeout(30000);
$sqlite_commands = [
	'INSERT',
	'INSERT',
	'INSERT',
	'INSERT',
	'UPDATE',
	'UPDATE',
	'SELECT',
	// 'DELETE',
];

if ($use_file_lock)
{
	$lock_fd = fopen($lock_path, 'c+');
	block_lock($lock_fd);
	echo $which_test . ': Obtained file level lock for table create.' . PHP_EOL;
}

$result = $db->query('PRAGMA main.synchronous=extra');
$result = $db->query('PRAGMA temp.synchronous=extra');
// $result = $db->query('PRAGMA main.locking_mode=EXCLUSIVE;');
// $result = $db->query('PRAGMA temp.locking_mode=EXCLUSIVE;');

// create table for data
$sql = 'CREATE TABLE IF NOT EXISTS cache (key VARCHAR PRIMARY KEY, value BLOB, ttl INTEGER)';

do
{
	echo $which_test . ': Attempting to build cache table.' . PHP_EOL;
	$result = $db->query($sql);
	if ($result === false)
	{
		echo 'Unable to create the table cache' . PHP_EOL;
	}
} while ($result === false);

sqlite_integrity_check($db, 'after attempt to build cache table');

$db->close();
unset($db);
if ($use_file_lock)
{
	shell_exec ('sync ' . $path);
//	sleep(1);
	echo $which_test . ': Releasing file level lock for table create.' . PHP_EOL;
	block_unlock($lock_fd);
	fclose($lock_fd);
	$lock_fd = null;
}

for ($i = 0; $i < $count ;$i ++)
{
	if (!isset($db))
	{
		if ($use_file_lock)
		{
			$lock_fd = fopen($lock_path, 'c+');
//			echo 'lock_fd = ' . print_r($lock_fd, true) . PHP_EOL;
			block_lock($lock_fd);
			echo $which_test . ',' . $i . ': Obtained file level lock.' . PHP_EOL;
//			sleep(2);
		}
		echo $which_test . ': ' . 'Attempting db reconnect' . PHP_EOL;
		$db = new Sqlite3($path);
		$db->busyTimeout(30000);
		$result = $db->query('PRAGMA main.synchronous=extra');
		$result = $db->query('PRAGMA temp.synchronous=extra');
// 		$result = $db->query('PRAGMA main.locking_mode=EXCLUSIVE;');
// 		$result = $db->query('PRAGMA temp.locking_mode=EXCLUSIVE;');
		sqlite_integrity_check($db, 'after obtaining lock file');

	}

	$command = $sqlite_commands[random_int(0, count($sqlite_commands) - 1)];
	switch ($command)
	{
		case 'INSERT':
			// keep the md5s around so we're not making a bunch of invalid queries
			$key = get_random_key(32);
			$key_cache[] = $key;
			$value = generate_json_blob(random_int(10, 20));
			$ttl = random_int(10000, 99999);
			$query = "INSERT OR IGNORE INTO cache (key, value, ttl) VALUES ('{$key}', '{$value}', {$ttl});";

			echo $which_test . ',' . $i . ': ' . 'Running ' . $command . ' for the key: ' . $key . PHP_EOL;
			$result = $db->query($query);
			if ($result === false)
			{
				echo $which_test . ': ' . 'Unable to ' . $command . ' the key: ' . $key . PHP_EOL;
			}
			break;
		case 'UPDATE':
			if (!empty($key_cache))
			{
				// update valid data
				$key = $key_cache[random_int(0, count($key_cache) - 1)];
				$value = generate_json_blob(random_int(10, 20));
				$query = "UPDATE cache SET value = '{$value}' WHERE key = '{$key}';";

				echo $which_test . ',' . $i . ': ' . 'Running ' . $command . ' for the key: ' . $key . PHP_EOL;
				$result = $db->query($query);

				if ($result === false)
				{
					echo $which_test . ': ' . 'Unable to ' . $command . ' the key: ' . $key . PHP_EOL;
				}
			}
			break;
		case 'SELECT':
		case 'DELETE':
			if (!empty($key_cache))
			{
				if (random_int(0, 1))
				{
					// do a potentially intentional miss
					$key = get_random_key(32);
				}
				else
				{
					// process valid data
					$key = $key_cache[random_int(0, count($key_cache) - 1)];
				}

				// construc the query
				if ($command == 'SELECT')
				{
					$query = "SELECT * FROM cache WHERE key = '{$key}';";
				}
				else
				{
					$query = "DELETE FROM cache WHERE key = '{$key}';";
				}

				echo $which_test . ',' . $i . ': ' . 'Running ' . $command . ' for the key: ' . $key . PHP_EOL;

				$result = $db->query($query);
				if ($result === false)
				{
					echo $which_test . ': ' . 'Unable to ' . $command . ' the key: ' . $key . PHP_EOL;
				}
			}
			break;
	}

	// force database reconnect ever 10 iterations
	if (($i + 1) % 10 == 0)
	{
		echo $which_test . ': ' . 'Disconnecting from database' . PHP_EOL;
		$db->close();
		// sleep(random_int(1, 1));
		$db->close();
		unset($db);

		if ($use_file_lock)
		{
			echo $which_test . ',' . $i . ': Releasing file level lock.' . PHP_EOL;
			shell_exec ('sync ' . $path);
//			sleep(1);

			block_unlock($lock_fd);
			fclose($lock_fd);
			$lock_fd = null;
		}
	}

	// Don't burn through things so fast (0.05 seconds)
	usleep(50000);
}

/**
 * Obtain lock on file.
 * @return void
 */
function block_lock($fp)
{
	if (flock($fp, LOCK_EX) === false)
	{
		echo 'Unable to obtain lock';
		return;
	}
}

function block_unlock($fp)
{
	flock($fp, LOCK_UN);
}

/**
 * @param int $length The length to read from dev urandom.
 * @return string Contents from dev urandom.
 */
function get_random_key(int $length): string
{
	return bin2hex(random_bytes($length));
}

/**
 * @param int $values The number of values to include in the json blob.
 * @return string A json blob.
 */
function generate_json_blob(int $values): string
{
	$blob = [];
	for ($i = 0; $i < $values; $i++)
	{
		$blob[get_random_key(32)] = get_random_key(128);
	}
	return json_encode($blob);
}

/**
 * @return void
 */
function sqlite_wait()
{
	echo "Sleeping in an attempt to gain a lock" . PHP_EOL;
	sleep(1);
}

function sqlite_integrity_check($db, $message)
{
	$result = $db->query('PRAGMA integrity_check');
	if ($result === false)
	{
		echo 'failed to run integrity_check.' . PHP_EOL;
		exit(1);
	}
	$result = $result->fetchArray();
	if ($result[0] != 'ok' || $result['integrity_check'] != 'ok')
	{
		echo $message . ': ' . print_r($result, true) . PHP_EOL;
		exit(1);
	}

}
