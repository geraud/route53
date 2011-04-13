# Route 53 command line tool

## Working with  zones

### List of the zones in your account
    # thor route53:zones

### Display the details of a zone
    # thor route53:show_zone ZDOG1234566P

### Create a new zone
    # thor route53:create_zone domain.com

### Remove a zone
    # thor route53:destroy_zone ZDOG1234566P

## Changing records

### List the records in a zone
    # thor route53:records ZDOG1234566P

### List a specific type of record in a zone
 The following code displays all the MX records a the zone

    # thor route53:records ZDOG1234566P mx
### Create a new record
The following code adds several MX records to your zone

    # thor route53:create_record ZDOG1234566P  -t mx  -n 'domain.com' -v  \
      '10 ASPMX.L.GOOGLE.COM.' \
      '20 ALT1.ASPMX.L.GOOGLE.COM.'  \
      '30 ALT2.ASPMX.L.GOOGLE.COM.'  \
      '40 ASPMX2.GOOGLEMAIL.COM.'

The following code adds a simple A record  to your zone

    # thor route53:create_record ZDOG1234566P  -t a  -n 'domain.com' -v \
      "10.0.1.150"

### Destroy a record

    # thor route53:destroy_record ZDOG1234566P 6beef71be5ed57e9fea145c46ddb86ddf2f6e235
