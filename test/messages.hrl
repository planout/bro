-record(message,
        {
         from = undefined,
         to = undefined,
         body = <<"">>
        }).

-record(not_exported_record,
        {
         x = undefined
        }).
