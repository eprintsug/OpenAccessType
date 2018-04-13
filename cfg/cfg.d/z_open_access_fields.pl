# Open Access type fields
# UZH CHANGE ZORA-623 2018/01/09/mb OA Status and DOAJ fields
@{ $c->{fields}->{eprint} } = ( @{ $c->{fields}->{eprint} }, (
        {
                'name' => 'oa_status',
                'type' => 'set',
                'options' => [
                        'gold',
                        'hybrid',
                        'green',
                        'closed'
                ],
                'input_style' => 'medium',
        },
        {
                'name' => 'doaj',
                'type' => 'boolean',
                'input_style' => 'radio',
        },
));
# END UZH CHANGE ZORA-623
