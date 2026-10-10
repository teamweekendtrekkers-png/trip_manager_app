import 'dart:convert';

/// Defaults copied from the existing homepage; kept in parity with the website.
const homepageSectionDefaultsJson = r'''
{
  "stats": {
    "enabled": true,
    "items": [
      {
        "id": "trips",
        "value": "683+",
        "label": "Trips Completed",
        "visible": true
      },
      {
        "id": "travellers",
        "value": "7.2k+",
        "label": "Happy Travellers",
        "visible": true
      },
      {
        "id": "rating",
        "value": "4.8⭐",
        "label": "Google Rating",
        "visible": true
      },
      {
        "id": "destinations",
        "value": "50+",
        "label": "Destinations",
        "visible": true
      }
    ]
  },
  "whyUs": {
    "enabled": true,
    "title": "Why Travel With Us?",
    "items": [
      {
        "id": "offbeat",
        "icon": "🗺️",
        "title": "Offbeat Destinations",
        "text": "We go where Google Maps doesn't. Hidden waterfalls, untouched valleys, and secret viewpoints away from tourist crowds.",
        "visible": true
      },
      {
        "id": "inclusive",
        "icon": "✅",
        "title": "All-Inclusive",
        "text": "Transport, stay, permits, food, guides & entry tickets - everything handled. No hidden charges, no surprises.",
        "visible": true
      },
      {
        "id": "vibe",
        "icon": "🎉",
        "title": "Vibe Over Volume",
        "text": "Small groups, music, bonfire nights & new friendships. Every trip feels like traveling with old friends.",
        "visible": true
      }
    ]
  },
  "reviews": {
    "enabled": true,
    "title": "Google Reviews",
    "rating": "4.8",
    "googleMapsUrl": "https://maps.app.goo.gl/6ZimFRc231p2BWMv6",
    "buttonLabel": "See All Reviews on Google →",
    "autoPlay": true,
    "intervalSeconds": 6,
    "items": [
      {
        "id": "review-1",
        "name": "Manish Singh",
        "date": "a week ago",
        "rating": 5,
        "text": "Just got back from an amazing weekend spiritual trip to Rameshwaram and Dhanushkodi! 🧘‍♀️🙏 The journey was so rejuvenating, and seeing the bridge at Dhanushkodi was absolutely breathtaking. 🌊",
        "photo": "https://lh3.googleusercontent.com/a-/ALV-UjXHVUSEuvKI6CKUHupOjMxwiwTWkz-N3WpR60Sry3W1_hyLcN180A=w72-h72-p-rp-mo-ba4-br100",
        "googleMapsUrl": "",
        "visible": true
      },
      {
        "id": "review-2",
        "name": "Pavan Shinde",
        "date": "4 months ago",
        "rating": 5,
        "text": "This was my first trip in Bangalore with an unknown group of people, but by the end of it, I genuinely felt like I'd made some amazing friends. Wonderful experience!",
        "photo": "https://lh3.googleusercontent.com/a/ACg8ocL6BOYdFlrubH2qQg4YaY7epbmpu_nlM3Htq27nFC64_64u3cEu=w72-h72-p-rp-mo-ba7-br100",
        "googleMapsUrl": "",
        "visible": true
      },
      {
        "id": "review-3",
        "name": "S N",
        "date": "4 months ago",
        "rating": 5,
        "text": "The guide Mr. Richee is a very humble guy. Who took care of each individual traveller. Patiently waiting for everyone to arrive and made sure no one was left out. Creates a comfort zone!",
        "photo": "https://lh3.googleusercontent.com/a-/ALV-UjWKrLJJZTHX0LGC9ltiPPKAFgO3chglSLiW-vzUW6zLdRbdaIOb-g=w72-h72-p-rp-mo-ba5-br100",
        "googleMapsUrl": "",
        "visible": true
      },
      {
        "id": "review-4",
        "name": "Harjinder Bhatti",
        "date": "3 months ago",
        "rating": 5,
        "text": "I went on a trip to Rameshwaram, Dhanushkodi, navagraha temples and Thanjavur Temple. My first solo trip and I quickly found comfort in the amazing people I met. 😃",
        "photo": "https://lh3.googleusercontent.com/a-/ALV-UjUE7_9pFqJN-1fn_l_kqDafhrkQfkhpnI_gKZlsGeBG8PHXpEBJ=w72-h72-p-rp-mo-br100",
        "googleMapsUrl": "",
        "visible": true
      },
      {
        "id": "review-5",
        "name": "Sandeep Reddy",
        "date": "2 months ago",
        "rating": 5,
        "text": "Amazing experience on Rameshwaram-Dhanushkodi trip! Our tour guide Vinayaka S was so kind and patient with all of us. Though we part ways, the memories we've made will always keep us connected.",
        "photo": "https://lh3.googleusercontent.com/a-/ALV-UjXs3IaRcUWq0K0ELrv3dMkqYTQ9T2uY6oV9Xmigxt7uBnQraye0=w72-h72-p-rp-mo-br100",
        "googleMapsUrl": "",
        "visible": true
      },
      {
        "id": "review-6",
        "name": "Uma Bhat",
        "date": "3 weeks ago",
        "rating": 5,
        "text": "Me and my friend booked for Rameshwaram and Tanjavur weekend package. Met many new people and spending these 2 days as a group was fun. Highly recommended!",
        "photo": "https://lh3.googleusercontent.com/a-/ALV-UjWv_1VanAp09wFyIUFNk2a9GExbFNDSBPyS6W3F9gVWX3o3ytg=w72-h72-p-rp-mo-br100",
        "googleMapsUrl": "",
        "visible": true
      }
    ]
  },
  "cta": {
    "enabled": true,
    "title": "Ready for Your Next Adventure?",
    "description": "Join 7,200+ happy travellers who've explored with us",
    "primaryLabel": "Browse Trips",
    "secondaryLabel": "WhatsApp Us"
  }
}
''';
Map<String, dynamic> homepageSectionDefaults() =>
    jsonDecode(homepageSectionDefaultsJson) as Map<String, dynamic>;
