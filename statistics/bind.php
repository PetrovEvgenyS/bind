<?php
	$cfg_src1 = "/root/statistics/query.log"; // Путь к лог-файлу BIND
	$cfg_drop1 = "/root/statistics/report";   // Путь к директории для сохранения логов
	$f = date('YmdHis');                    // Текущая дата и время (ГГГГММДДЧЧММСС)
	$d = date('Y.m');                       // Текущая дата (ГГГГ.ММ)
	if (!file_exists($cfg_drop1.$d))        // Проверка существования директории
		mkdir($cfg_drop1.$d);               // Создание директории, если не существует
	exec('systemctl stop bind9');           // Остановка службы named
	copy($cfg_src1, $cfg_drop1.$d.'/'.$f);  // Копирование лога в новую директорию
	// exec('rm '.$cfg_src1);                  // Удаление исходного лог-файла
	exec('systemctl start bind9');          // Запуск службы named
?>