local CMS_ERROR = {
    [1] = {
        title = "Unassigned (unallocated) number",
        title_ru = "Неназначенный (нераспределённый номер)",
        description_ru = "Номер имеет правильный формат, но не зарегистрирован в сети оператора."
    },
    [8] = {
        title = "Operator determined barring",
        title_ru = "Блокировка оператором",
        description_ru = "Оператор запретил исходящие SMS для данного абонента."
    },
    [10] = {
        title = "Call barred",
        title_ru = "Вызов заблокирован",
        description_ru = "Активирована услуга блокировки исходящих SMS для указанного номера."
    },
    [17] = {
        title = "Network failure",
        title_ru = "Сбой сети",
        description_ru = "Ошибка MSC из-за проблем в PLMN (например, сбои в MAP-протоколе)."
    },
    [21] = {
        title = "Short message transfer rejected",
        title_ru = "Передача сообщения отклонена",
        description_ru = "Сетевое оборудование отказало в обработке SMS без указания конкретной причины."
    },
    [22] = {
        title = "Congestion OR Memory capacity exceeded",
        title_ru = "Перегрузка сети или переполнение памяти",
        description_ru = "Сеть перегружена (нет свободных каналов) ИЛИ память устройства/SIM заполнена."
    },
    [27] = {
        title = "Destination out of service",
        title_ru = "Абонент вне зоны обслуживания",
        description_ru = "Ошибка доставки из-за неработоспособности интерфейса получателя (выключен телефон, сбой физического уровня)."
    },
    [28] = {
        title = "Unidentified subscriber",
        title_ru = "Абонент не идентифицирован",
        description_ru = "IMSI не зарегистрирован в PLMN (проблема с регистрацией в сети оператора)."
    },
    [29] = {
        title = "Facility rejected",
        title_ru = "Услуга отклонена",
        description_ru = "PLMN не поддерживает запрошенную дополнительную услугу."
    },
    [30] = {
        title = "Unknown subscriber",
        title_ru = "Неизвестный абонент",
        description_ru = "IMSI или номер не зарегистрирован в HLR."
    },
    [38] = {
        title = "Network out of order",
        title_ru = "Сеть неисправна",
        description_ru = "Критический сбой сетевой инфраструктуры (длительный простой)."
    },
    [41] = {
        title = "Temporary failure",
        title_ru = "Временный сбой",
        description_ru = "Кратковременная неисправность сети (можно повторить попытку)."
    },
    [42] = {
        title = "Congestion",
        title_ru = "Перегрузка сети",
        description_ru = "Сервис SMS недоступен из-за высокой нагрузки."
    },
    [47] = {
        title = "Resources unavailable, unspecified",
        title_ru = "Ресурсы недоступны",
        description_ru = "Общая ошибка недоступности ресурсов (когда не применимы другие коды)."
    },
    [50] = {
        title = "Requested facility not subscribed",
        title_ru = "Услуга не подключена",
        description_ru = "У абонента отсутствует необходимая подписка на сервис."
    },
    [69] = {
        title = "Requested facility not implemented",
        title_ru = "Услуга не реализована",
        description_ru = "Сетевая функция не поддерживается оператором."
    },
    [81] = {
        title = "Invalid short message transfer reference value",
        title_ru = "Неверный идентификатор сообщения",
        description_ru = "Получен недействительный SM reference number."
    },
    [95] = {
        title = "Invalid message, unspecified",
        title_ru = "Некорректное сообщение",
        description_ru = "Общая ошибка формата."
    },
    [96] = {
        title = "Invalid mandatory information",
        title_ru = "Некорректная обязательная информация",
        description_ru = "Отсутствует или содержит ошибки обязательный информационный элемент."
    },
    [97] = {
        title = "Message type non-existent or not implemented",
        title_ru = "Тип сообщения не существует или не поддерживается",
        description_ru = "Получен неизвестный или нереализованный тип сообщения."
    },
    [98] = {
        title = "Message not compatible with short message protocol state",
        title_ru = "Несовместимость с состоянием SMS-протокола",
        description_ru = "Сообщение недопустимо в текущем состоянии протокола передачи SMS."
    },
    [99] = {
        title = "Information element non-existent or not implemented",
        title_ru = "Информационный элемент не существует или не поддерживается",
        description_ru = "Получен неизвестный или нереализованный IE (идентификатор элемента)."
    },
    [111] = {
        title = "Protocol error, unspecified",
        title_ru = "Ошибка протокола",
        description_ru = "Общая ошибка протокола (когда другие коды не применимы)."
    },
    [127] = {
        title = "Interworking, unspecified",
        title_ru = "Ошибка межсетевого взаимодействия",
        description_ru = "Проблема взаимодействия с сетью, не предоставляющей коды ошибок."
    },
    [128] = {
        title = "Telematic interworking not supported",
        title_ru = "Телематическое взаимодействие не поддерживается",
        description_ru = "Сеть не поддерживает телематические интерфейсы (бинарные данные и др.)."
    },
    [129] = {
        title = "Short message Type 0 not supported",
        title_ru = "Сообщения Type 0 не поддерживаются",
        description_ru = "Устройство не поддерживает SMS Type 0 (флеш-сообщения)."
    },
    [130] = {
        title = "Cannot replace short message",
        title_ru = "Невозможно заменить сообщение",
        description_ru = "Отсутствует сообщение с указанным ID для замены."
    },
    [143] = {
        title = "Unspecified TP-PID error",
        title_ru = "Ошибка TP-PID",
        description_ru = "Общая ошибка Protocol Identifier (когда другие коды не применимы)."
    },
    [144] = {
        title = "Data coding scheme (alphabet) not supported",
        title_ru = "Схема кодирования не поддерживается",
        description_ru = "Устройство не поддерживает указанную DCS (например, UCS2)."
    },
    [145] = {
        title = "Message class not supported",
        title_ru = "Класс сообщения не поддерживается",
        description_ru = "Устройство не поддерживает указанный класс сообщения."
    },
    [159] = {
        title = "Unspecified TP-DCS error",
        title_ru = "Ошибка TP-DCS",
        description_ru = "Общая ошибка Data Coding Scheme (когда другие коды не применимы)."
    },
    [160] = {
        title = "Command cannot be actioned",
        title_ru = "Невозможно выполнить команду",
        description_ru = "Команда противоречит текущему состоянию системы."
    },
    [161] = {
        title = "Command unsupported",
        title_ru = "Команда не поддерживается",
        description_ru = "Устройство не распознаёт полученную команду."
    },
    [175] = {
        title = "Unspecified TP-Command error",
        title_ru = "Ошибка TP-Command",
        description_ru = "Общая ошибка обработки команды (когда другие коды не применимы)."
    },
    [176] = {
        title = "TPDU not supported",
        title_ru = "TPDU не поддерживается",
        description_ru = "Неподдерживаемый тип Transfer Protocol Data Unit."
    },
    [192] = {
        title = "SC busy",
        title_ru = "SMS-центр перегружен",
        description_ru = "SMS-центр (SMSC) временно недоступен из-за высокой нагрузки."
    },
    [193] = {
        title = "No SC subscription",
        title_ru = "Отсутствует подписка в SMS-центре",
        description_ru = "Абонент не зарегистрирован в SMS-центре."
    },
    [194] = {
        title = "SC system failure",
        title_ru = "Сбой системы SMS-центра",
        description_ru = "Критическая ошибка в SMS-центре оператора."
    },
    [195] = {
        title = "Invalid SME address",
        title_ru = "Неверный адрес SME",
        description_ru = "Ошибка в формате номера отправителя/получателя."
    },
    [196] = {
        title = "Destination SME barred",
        title_ru = "Получатель SME заблокирован",
        description_ru = "Оператор заблокировал получение SMS для этого номера."
    },
    [197] = {
        title = "SM Rejected-Duplicate SM",
        title_ru = "Отклонено: дубликат SMS-центра",
        description_ru = "Обнаружено дублирующееся сообщение с таким же идентификатором."
    },
    [198] = {
        title = "TP-VPF not supported",
        title_ru = "TP-VPF не поддерживается",
        description_ru = "Неподдерживаемый формат Validity Period Format."
    },
    [199] = {
        title = "TP-VP not supported",
        title_ru = "TP-VP не поддерживается",
        description_ru = "Некорректное значение Validity Period."
    },
    [208] = {
        title = "SIM SMS storage full",
        title_ru = "Память SIM для SMS заполнена",
        description_ru = "Невозможно сохранить сообщение на SIM-карте."
    },
    [209] = {
        title = "No SMS storage capability in SIM",
        title_ru = "SIM не поддерживает хранение SMS",
        description_ru = "SIM-карта не имеет функционала для хранения SMS."
    },
    [210] = {
        title = "Error in MS",
        title_ru = "Ошибка в мобильном устройстве",
        description_ru = "Внутренняя ошибка мобильного станции (MS)."
    },
    [211] = {
        title = "Memory Capacity Exceeded",
        title_ru = "Превышена ёмкость памяти",
        description_ru = "Переполнение внутренней памяти устройства."
    },
    [212] = {
        title = "SIM Application Toolkit Busy",
        title_ru = "SIM Application Toolkit занят",
        description_ru = "SIM-карта обрабатывает другую команду."
    },
    [255] = {
        title = "Unspecified error cause",
        title_ru = "Неопределённая ошибка",
        description_ru = "Ошибка без указания конкретной причины."
    },
    [300] = {
        title = "ME failure",
        title_ru = "Ошибка мобильного оборудования",
        description_ru = "Аппаратный или программный сбой мобильного устройства (ME)."
    },
    [301] = {
        title = "SMS service of ME reserved",
        title_ru = "Сервис SMS зарезервирован",
        description_ru = "Функция SMS временно недоступна (например, во время вызова)."
    },
    [302] = {
        title = "Operation not allowed",
        title_ru = "Операция не разрешена",
        description_ru = "Операция не разрешена (например, в режиме полёта)."
    },
    [303] = {
        title = "Operation not supported",
        title_ru = "Операция не поддерживается",
        description_ru = "Устройство не поддерживает запрошенную операцию."
    },
    [304] = {
        title = "Invalid PDU mode parameter",
        title_ru = "Неверный параметр PDU-режима",
        description_ru = "Ошибка в параметре режима PDU."
    },
    [305] = {
        title = "Invalid text mode parameter",
        title_ru = "Неверный параметр текстового режима",
        description_ru = "Ошибка в параметре текстового режима."
    },
    [310] = {
        title = "SIM not inserted",
        title_ru = "SIM-карта не вставлена",
        description_ru = "Устройство не обнаружило SIM-карту."
    },
    [311] = {
        title = "SIM PIN required",
        title_ru = "Требуется PIN-код SIM",
        description_ru = "SIM-карта заблокирована PIN-кодом."
    },
    [312] = {
        title = "PH-SIM PIN required",
        title_ru = "Требуется PIN-код устройства",
        description_ru = "Активирована блокировка устройства по PIN."
    },
    [313] = {
        title = "SIM failure",
        title_ru = "Ошибка SIM-карты",
        description_ru = "Аппаратный сбой или повреждение SIM-карты."
    },
    [314] = {
        title = "SIM busy",
        title_ru = "SIM-карта занята",
        description_ru = "SIM-карта обрабатывает другую команду."
    },
    [315] = {
        title = "SIM wrong",
        title_ru = "Неверная SIM-карта",
        description_ru = "Проблема аутентификации или недействительная карта."
    },
    [316] = {
        title = "SIM PUK required",
        title_ru = "Требуется PUK-код",
        description_ru = "Превышено количество попыток ввода PIN."
    },
    [317] = {
        title = "SIM PIN2 required",
        title_ru = "Требуется PIN2-код",
        description_ru = "Необходим второй PIN-код для операции."
    },
    [318] = {
        title = "SIM PUK2 required",
        title_ru = "Требуется PUK2-код",
        description_ru = "Превышено количество попыток ввода PIN2."
    },
    [320] = {
        title = "Memory failure",
        title_ru = "Ошибка памяти",
        description_ru = "Сбой внутренней памяти устройства."
    },
    [321] = {
        title = "Invalid memory index",
        title_ru = "Неверный индекс памяти",
        description_ru = "Указана несуществующая ячейка памяти."
    },
    [322] = {
        title = "Memory full",
        title_ru = "Память заполнена",
        description_ru = "Недостаточно памяти для хранения сообщения."
    },
    [330] = {
        title = "SMSC address unknown",
        title_ru = "Неизвестный адрес SMSC",
        description_ru = "В устройстве не настроен номер SMS-центра."
    },
    [331] = {
        title = "No network service",
        title_ru = "Сеть недоступна",
        description_ru = "Устройство не может подключиться к сети."
    },
    [332] = {
        title = "Network timeout",
        title_ru = "Таймаут сети",
        description_ru = "Превышено время ожидания ответа сети."
    },
    [340] = {
        title = "No +CNMA acknowledgement expected",
        title_ru = "Подтверждение +CNMA не ожидается",
        description_ru = "SMS-центр запросил подтверждение доставки (+CNMA), но устройство работает в режиме, где это не поддерживается (например, текстовый режим)."
    },
    [500] = {
        title = "Unknown error",
        title_ru = "Неизвестная ошибка",
        description_ru = "Неопределённая ошибка."
    },
    [512] = {
        title = "Manufacturer specific",
        title_ru = "Manufacturer specific",
        description_ru = "Manufacturer specific"
    },
    tsmodem_timeout = {
        title = "Tsmodem timeout",
        title_ru = "Tsmodem таймаут",
        description_ru = "Превышено время ожидания ответа от модуля Tsmodem",
    },
}

return CMS_ERROR