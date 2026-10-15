import 'package:flutter_test/flutter_test.dart';
import 'package:trip_manager_app/services/commerce_settings_service.dart';
import 'package:trip_manager_app/services/trip_date_utils.dart';
import 'package:trip_manager_app/services/trips_parser.dart';

void main() {
  test('legacy account is retained while the backup starts empty', () {
    final config=CommerceSettingsService.normalize({'version':1,'payment':{'upiId':'original@upi','qrImage':'images/original.png','receiverName':'Original'},'showCoupons':true,'coupons':[]});
    final p=config['payment'];
    expect(p['checkoutVersion'],2);expect(p['mode'],'direct');
    expect(p['profiles'][0]['upiId'],'original@upi');expect(p['profiles'][0]['qrImage'],'images/original.png');
    expect(p['profiles'][1]['upiId'],'');expect(p['requestTripIds'],isEmpty);
  });
  test('switching accounts derives all public fields from the same profile', () {
    final config=CommerceSettingsService.defaults(),p=config['payment'];
    p['profiles'][1]={'id':'backup','label':'Backup','upiId':'backup@upi','receiverName':'Backup receiver','qrImage':'images/backup.png'};
    p['activeProfileId']='backup';
    final actual=CommerceSettingsService.normalize(config);
    expect(actual['payment']['upiId'],'backup@upi');expect(actual['payment']['receiverName'],'Backup receiver');expect(actual['payment']['qrImage'],'images/backup.png');
    CommerceSettingsService.validate(actual);
    final invalid=CommerceSettingsService.normalize(config);invalid['payment']['profiles'][1]['qrImage']='https://evil.test/qr.png';
    expect(()=>CommerceSettingsService.validate(invalid),throwsFormatException);
  });
  test('closed departures survive source parsing and stay unbookable until reopened', () {
    final source='const tripsData={demo:{title:"Demo",price:"₹4499",image:"images/demo.jpg",isActive:true,availableDates:["Dec 20-22, 2099"],closedDepartures:["2099-12-20/2099-12-22"]}};';
    final trip=TripsParser.parseTripsData(source).single;
    expect(trip['closedDepartures'],['2099-12-20/2099-12-22']);
    expect(TripDateUtils.getUpcomingDateRanges(trip,referenceDate:DateTime.utc(2099,12,1)),isEmpty);
    trip['closedDepartures']=<String>[];
    expect(TripDateUtils.getUpcomingDateRanges(trip,referenceDate:DateTime.utc(2099,12,1)),hasLength(1));
  });
}
