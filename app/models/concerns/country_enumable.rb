# frozen_string_literal: true

module CountryEnumable
  extend ActiveSupport::Concern

  module ClassMethods
    def has_country_enum(enum_name = :country)
      enum enum_name, self.country_enum_list, prefix: :country
    end

    private

    def country_enum_list
      {
        US: 215,
        IN: 104,
        CA: 41,
        AD: 6,
        AE: 235,
        AF: 1,
        AG: 10,
        AI: 8,
        AL: 3,
        AM: 12,
        AO: 7,
        AQ: 9,
        AR: 11,
        AS: 5,
        AT: 15,
        AU: 14,
        AW: 13,
        AX: 2,
        AZ: 16,
        BA: 29,
        BB: 20,
        BD: 19,
        BE: 22,
        BF: 36,
        BG: 35,
        BH: 18,
        BI: 37,
        BJ: 24,
        BL: 186,
        BM: 25,
        BN: 34,
        BO: 27,
        BQ: 28,
        BR: 32,
        BS: 17,
        BT: 26,
        BV: 31,
        BW: 30,
        BY: 21,
        BZ: 23,
        CC: 48,
        CD: 52,
        CF: 43,
        CG: 51,
        CH: 217,
        CI: 55,
        CK: 53,
        CL: 45,
        CM: 40,
        CN: 46,
        CO: 49,
        CR: 54,
        CU: 57,
        CV: 38,
        CW: 58,
        CX: 47,
        CY: 59,
        CZ: 60,
        DE: 84,
        DJ: 62,
        DK: 61,
        DM: 63,
        DO: 64,
        DZ: 4,
        EC: 65,
        EE: 70,
        EG: 66,
        EH: 246,
        ER: 69,
        ES: 210,
        ET: 72,
        FI: 76,
        FJ: 75,
        FK: 73,
        FM: 145,
        FO: 74,
        FR: 77,
        GA: 81,
        GB: 236,
        GD: 89,
        GE: 83,
        GF: 78,
        GG: 93,
        GH: 85,
        GI: 86,
        GL: 88,
        GM: 82,
        GN: 94,
        GP: 90,
        GQ: 68,
        GR: 87,
        GS: 208,
        GT: 92,
        GU: 91,
        GW: 95,
        GY: 96,
        HK: 101,
        HM: 98,
        HN: 100,
        HR: 56,
        HT: 97,
        HU: 102,
        ID: 105,
        IE: 108,
        IL: 110,
        IM: 109,
        IO: 33,
        IQ: 107,
        IR: 106,
        IS: 103,
        IT: 111,
        JE: 114,
        JM: 112,
        JO: 115,
        JP: 113,
        KE: 117,
        KG: 122,
        KH: 39,
        KI: 118,
        KM: 50,
        KN: 188,
        KP: 119,
        KR: 120,
        KW: 121,
        KY: 42,
        KZ: 116,
        LA: 123,
        LB: 125,
        LC: 189,
        LI: 129,
        LK: 211,
        LR: 127,
        LS: 126,
        LT: 130,
        LU: 131,
        LV: 124,
        LY: 128,
        MA: 151,
        MC: 147,
        MD: 146,
        ME: 149,
        MF: 190,
        MG: 133,
        MH: 139,
        MK: 165,
        ML: 137,
        MM: 153,
        MN: 148,
        MO: 132,
        MP: 166,
        MQ: 140,
        MR: 141,
        MS: 150,
        MT: 138,
        MU: 142,
        MV: 136,
        MW: 134,
        MX: 144,
        MY: 135,
        MZ: 152,
        NA: 154,
        NC: 158,
        NE: 161,
        NF: 164,
        NG: 162,
        NI: 160,
        NL: 157,
        NO: 167,
        NP: 156,
        NR: 155,
        NU: 163,
        NZ: 159,
        OM: 168,
        PA: 172,
        PE: 175,
        PF: 79,
        PG: 173,
        PH: 176,
        PK: 169,
        PL: 178,
        PM: 191,
        PN: 177,
        PR: 180,
        PS: 171,
        PT: 179,
        PW: 170,
        PY: 174,
        QA: 181,
        RE: 182,
        RO: 183,
        RS: 198,
        RU: 184,
        RW: 185,
        SA: 196,
        SB: 205,
        SC: 199,
        SD: 212,
        SE: 216,
        SG: 201,
        SH: 187,
        SI: 204,
        SJ: 214,
        SK: 203,
        SL: 200,
        SM: 194,
        SN: 197,
        SO: 206,
        SR: 213,
        SS: 209,
        ST: 195,
        SV: 67,
        SX: 202,
        SY: 218,
        SZ: 71,
        TC: 231,
        TD: 44,
        TF: 80,
        TG: 224,
        TH: 222,
        TJ: 220,
        TK: 225,
        TL: 223,
        TM: 230,
        TO: 226,
        TR: 229,
        TT: 227,
        TV: 232,
        TW: 219,
        TZ: 221,
        UA: 234,
        UG: 233,
        UM: 237,
        UY: 238,
        UZ: 239,
        VA: 99,
        VC: 192,
        VE: 241,
        VG: 243,
        VI: 244,
        VN: 242,
        VU: 240,
        WF: 245,
        WS: 193,
        YE: 247,
        YT: 143,
        ZA: 207,
        ZM: 248,
        ZW: 249,
      }
    end
  end

end
