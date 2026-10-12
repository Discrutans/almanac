String formatYdbConnectError(Object error) {
  final text = error.toString();
  if (text.contains('RESOURCE_EXHAUSTED') ||
      text.contains('ResourceExhausted')) {
    return 'Лимит Yandex Cloud исчерпан (RESOURCE_EXHAUSTED). '
        'Подождите 1–2 минуты и проверьте квоты serverless YDB.';
  }
  return text;
}
