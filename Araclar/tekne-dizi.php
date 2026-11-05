<?php
// Kullanım: php tekne-dizi.php dosya.php  → dosyanın başındaki $items / $liste ve $K değerlerini JSON yazar
$kaynak = file_get_contents($argv[1]);
$bas = strpos($kaynak, '<?php') + 5;
$son = strpos($kaynak, '?>', $bas);
$kod = substr($kaynak, $bas, $son - $bas);
$kod = str_replace(array('declare(strict_types=1);', 'session_start();'), '', $kod);
$_SESSION = array('user_id' => 1, 'role' => 'personel');
eval($kod);
$cikti = array();
if (isset($items)) { $cikti['items'] = $items; }
if (isset($liste)) { $cikti['liste'] = $liste; }
echo json_encode($cikti, JSON_UNESCAPED_UNICODE | JSON_PRETTY_PRINT);
