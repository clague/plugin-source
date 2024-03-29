#include <sourcemod>
#include <globalvariables>
#include <mapchooser>

#pragma newdecls required
#pragma semicolon 1

#define PLUGIN_VERSION  "1.0"

public Plugin myinfo =
{
    name        = "ColorVariables",
    author      = "clagura",
    description = "Provide simple function.",
    version     = PLUGIN_VERSION,
    url         = "https://steamcommunity.com/id/wwwttthhh/"
};

StringMap g_hChatColors;
bool g_bMapChooser;
bool g_bProtobuf;

static void AddChatColors() {
    if (IsValidHandle(g_hChatColors)) {
        g_hChatColors = new StringMap();
    }

    g_hChatColors.SetString("default", "\x01");
    g_hChatColors.SetString("teamcolor", "\x03");

    switch (GetEngineVersion()) {
        case Engine_CSS, Engine_DODS, Engine_HL2DM, Engine_Insurgency, Engine_SDK2013, Engine_TF2: {
            g_hChatColors.SetString("aliceblue", "\x07F0F8FF");
            g_hChatColors.SetString("allies", "\x074D7942");
            g_hChatColors.SetString("ancient", "\x07EB4B4B");
            g_hChatColors.SetString("antiquewhite", "\x07FAEBD7");
            g_hChatColors.SetString("aqua", "\x0700FFFF");
            g_hChatColors.SetString("aquamarine", "\x077FFFD4");
            g_hChatColors.SetString("arcana", "\x07ADE55C");
            g_hChatColors.SetString("axis", "\x07FF4040");
            g_hChatColors.SetString("azure", "\x07007FFF");
            g_hChatColors.SetString("beige", "\x07F5F5DC");
            g_hChatColors.SetString("bisque", "\x07FFE4C4");
            g_hChatColors.SetString("black", "\x07000000");
            g_hChatColors.SetString("blanchedalmond", "\x07FFEBCD");
            g_hChatColors.SetString("blue", "\x0799CCFF");
            g_hChatColors.SetString("blueviolet", "\x078A2BE2");
            g_hChatColors.SetString("brown", "\x07A52A2A");
            g_hChatColors.SetString("burlywood", "\x07DEB887");
            g_hChatColors.SetString("cadetblue", "\x075F9EA0");
            g_hChatColors.SetString("chartreuse", "\x077FFF00");
            g_hChatColors.SetString("chocolate", "\x07D2691E");
            g_hChatColors.SetString("collectors", "\x07AA0000");
            g_hChatColors.SetString("common", "\x07B0C3D9");
            g_hChatColors.SetString("community", "\x0770B04A");
            g_hChatColors.SetString("coral", "\x07FF7F50");
            g_hChatColors.SetString("cornflowerblue", "\x076495ED");
            g_hChatColors.SetString("cornsilk", "\x07FFF8DC");
            g_hChatColors.SetString("corrupted", "\x07A32C2E");
            g_hChatColors.SetString("crimson", "\x07DC143C");
            g_hChatColors.SetString("cyan", "\x0700FFFF");
            g_hChatColors.SetString("darkblue", "\x0700008B");
            g_hChatColors.SetString("darkcyan", "\x07008B8B");
            g_hChatColors.SetString("darkgoldenrod", "\x07B8860B");
            g_hChatColors.SetString("darkgray", "\x07A9A9A9");
            g_hChatColors.SetString("darkgrey", "\x07A9A9A9");
            g_hChatColors.SetString("darkgreen", "\x07006400");
            g_hChatColors.SetString("darkkhaki", "\x07BDB76B");
            g_hChatColors.SetString("darkmagenta", "\x078B008B");
            g_hChatColors.SetString("darkolivegreen", "\x07556B2F");
            g_hChatColors.SetString("darkorange", "\x07FF8C00");
            g_hChatColors.SetString("darkorchid", "\x079932CC");
            g_hChatColors.SetString("darkred", "\x078B0000");
            g_hChatColors.SetString("darksalmon", "\x07E9967A");
            g_hChatColors.SetString("darkseagreen", "\x078FBC8F");
            g_hChatColors.SetString("darkslateblue", "\x07483D8B");
            g_hChatColors.SetString("darkslategray", "\x072F4F4F");
            g_hChatColors.SetString("darkslategrey", "\x072F4F4F");
            g_hChatColors.SetString("darkturquoise", "\x0700CED1");
            g_hChatColors.SetString("darkviolet", "\x079400D3");
            g_hChatColors.SetString("deeppink", "\x07FF1493");
            g_hChatColors.SetString("deepskyblue", "\x0700BFFF");
            g_hChatColors.SetString("dimgray", "\x07696969");
            g_hChatColors.SetString("dimgrey", "\x07696969");
            g_hChatColors.SetString("dodgerblue", "\x071E90FF");
            g_hChatColors.SetString("exalted", "\x07CCCCCD");
            g_hChatColors.SetString("firebrick", "\x07B22222");
            g_hChatColors.SetString("floralwhite", "\x07FFFAF0");
            g_hChatColors.SetString("forestgreen", "\x07228B22");
            g_hChatColors.SetString("frozen", "\x074983B3");
            g_hChatColors.SetString("fuchsia", "\x07FF00FF");
            g_hChatColors.SetString("fullblue", "\x070000FF");
            g_hChatColors.SetString("fullred", "\x07FF0000");
            g_hChatColors.SetString("gainsboro", "\x07DCDCDC");
            g_hChatColors.SetString("genuine", "\x074D7455");
            g_hChatColors.SetString("ghostwhite", "\x07F8F8FF");
            g_hChatColors.SetString("gold", "\x07FFD700");
            g_hChatColors.SetString("goldenrod", "\x07DAA520");
            g_hChatColors.SetString("gray", "\x03");
            g_hChatColors.SetString("grey", "\x03");
            g_hChatColors.SetString("green", "\x04");
            g_hChatColors.SetString("greenyellow", "\x07ADFF2F");
            g_hChatColors.SetString("haunted", "\x0738F3AB");
            g_hChatColors.SetString("honeydew", "\x07F0FFF0");
            g_hChatColors.SetString("hotpink", "\x07FF69B4");
            g_hChatColors.SetString("immortal", "\x07E4AE33");
            g_hChatColors.SetString("indianred", "\x07CD5C5C");
            g_hChatColors.SetString("indigo", "\x074B0082");
            g_hChatColors.SetString("ivory", "\x07FFFFF0");
            g_hChatColors.SetString("khaki", "\x07F0E68C");
            g_hChatColors.SetString("lavender", "\x07E6E6FA");
            g_hChatColors.SetString("lavenderblush", "\x07FFF0F5");
            g_hChatColors.SetString("lawngreen", "\x077CFC00");
            g_hChatColors.SetString("legendary", "\x07D32CE6");
            g_hChatColors.SetString("lemonchiffon", "\x07FFFACD");
            g_hChatColors.SetString("lightblue", "\x07ADD8E6");
            g_hChatColors.SetString("lightcoral", "\x07F08080");
            g_hChatColors.SetString("lightcyan", "\x07E0FFFF");
            g_hChatColors.SetString("lightgoldenrodyellow", "\x07FAFAD2");
            g_hChatColors.SetString("lightgray", "\x07D3D3D3");
            g_hChatColors.SetString("lightgrey", "\x07D3D3D3");
            g_hChatColors.SetString("lightgreen", "\x0799FF99");
            g_hChatColors.SetString("lightpink", "\x07FFB6C1");
            g_hChatColors.SetString("lightsalmon", "\x07FFA07A");
            g_hChatColors.SetString("lightseagreen", "\x0720B2AA");
            g_hChatColors.SetString("lightskyblue", "\x0787CEFA");
            g_hChatColors.SetString("lightslategray", "\x07778899");
            g_hChatColors.SetString("lightslategrey", "\x07778899");
            g_hChatColors.SetString("lightsteelblue", "\x07B0C4DE");
            g_hChatColors.SetString("lightyellow", "\x07FFFFE0");
            g_hChatColors.SetString("lime", "\x0700FF00");
            g_hChatColors.SetString("limegreen", "\x0732CD32");
            g_hChatColors.SetString("linen", "\x07FAF0E6");
            g_hChatColors.SetString("magenta", "\x07FF00FF");
            g_hChatColors.SetString("maroon", "\x07800000");
            g_hChatColors.SetString("mediumaquamarine", "\x0766CDAA");
            g_hChatColors.SetString("mediumblue", "\x070000CD");
            g_hChatColors.SetString("mediumorchid", "\x07BA55D3");
            g_hChatColors.SetString("mediumpurple", "\x079370D8");
            g_hChatColors.SetString("mediumseagreen", "\x073CB371");
            g_hChatColors.SetString("mediumslateblue", "\x077B68EE");
            g_hChatColors.SetString("mediumspringgreen", "\x0700FA9A");
            g_hChatColors.SetString("mediumturquoise", "\x0748D1CC");
            g_hChatColors.SetString("mediumvioletred", "\x07C71585");
            g_hChatColors.SetString("midnightblue", "\x07191970");
            g_hChatColors.SetString("mintcream", "\x07F5FFFA");
            g_hChatColors.SetString("mistyrose", "\x07FFE4E1");
            g_hChatColors.SetString("moccasin", "\x07FFE4B5");
            g_hChatColors.SetString("mythical", "\x078847FF");
            g_hChatColors.SetString("navajowhite", "\x07FFDEAD");
            g_hChatColors.SetString("navy", "\x07000080");
            g_hChatColors.SetString("normal", "\x07B2B2B2");
            g_hChatColors.SetString("oldlace", "\x07FDF5E6");
            g_hChatColors.SetString("olive", "\x079EC34F");
            g_hChatColors.SetString("olivedrab", "\x076B8E23");
            g_hChatColors.SetString("orange", "\x07FFA500");
            g_hChatColors.SetString("orangered", "\x07FF4500");
            g_hChatColors.SetString("orchid", "\x07DA70D6");
            g_hChatColors.SetString("palegoldenrod", "\x07EEE8AA");
            g_hChatColors.SetString("palegreen", "\x0798FB98");
            g_hChatColors.SetString("paleturquoise", "\x07AFEEEE");
            g_hChatColors.SetString("palevioletred", "\x07D87093");
            g_hChatColors.SetString("papayawhip", "\x07FFEFD5");
            g_hChatColors.SetString("peachpuff", "\x07FFDAB9");
            g_hChatColors.SetString("peru", "\x07CD853F");
            g_hChatColors.SetString("pink", "\x07FFC0CB");
            g_hChatColors.SetString("plum", "\x07DDA0DD");
            g_hChatColors.SetString("powderblue", "\x07B0E0E6");
            g_hChatColors.SetString("purple", "\x07800080");
            g_hChatColors.SetString("rare", "\x074B69FF");
            g_hChatColors.SetString("red", "\x07FF4040");
            g_hChatColors.SetString("rosybrown", "\x07BC8F8F");
            g_hChatColors.SetString("royalblue", "\x074169E1");
            g_hChatColors.SetString("saddlebrown", "\x078B4513");
            g_hChatColors.SetString("salmon", "\x07FA8072");
            g_hChatColors.SetString("sandybrown", "\x07F4A460");
            g_hChatColors.SetString("seagreen", "\x072E8B57");
            g_hChatColors.SetString("seashell", "\x07FFF5EE");
            g_hChatColors.SetString("selfmade", "\x0770B04A");
            g_hChatColors.SetString("sienna", "\x07A0522D");
            g_hChatColors.SetString("silver", "\x07C0C0C0");
            g_hChatColors.SetString("skyblue", "\x0787CEEB");
            g_hChatColors.SetString("slateblue", "\x076A5ACD");
            g_hChatColors.SetString("slategray", "\x07708090");
            g_hChatColors.SetString("slategrey", "\x07708090");
            g_hChatColors.SetString("snow", "\x07FFFAFA");
            g_hChatColors.SetString("springgreen", "\x0700FF7F");
            g_hChatColors.SetString("steelblue", "\x074682B4");
            g_hChatColors.SetString("strange", "\x07CF6A32");
            g_hChatColors.SetString("tan", "\x07D2B48C");
            g_hChatColors.SetString("teal", "\x07008080");
            g_hChatColors.SetString("thistle", "\x07D8BFD8");
            g_hChatColors.SetString("tomato", "\x07FF6347");
            g_hChatColors.SetString("turquoise", "\x0740E0D0");
            g_hChatColors.SetString("uncommon", "\x07B0C3D9");
            g_hChatColors.SetString("unique", "\x07FFD700");
            g_hChatColors.SetString("unusual", "\x078650AC");
            g_hChatColors.SetString("valve", "\x07A50F79");
            g_hChatColors.SetString("vintage", "\x07476291");
            g_hChatColors.SetString("violet", "\x07EE82EE");
            g_hChatColors.SetString("wheat", "\x07F5DEB3");
            g_hChatColors.SetString("white", "\x07FFFFFF");
            g_hChatColors.SetString("whitesmoke", "\x07F5F5F5");
            g_hChatColors.SetString("yellow", "\x07FFFF00");
            g_hChatColors.SetString("yellowgreen", "\x079ACD32");
        }
        case Engine_Left4Dead, Engine_Left4Dead2: {
            g_hChatColors.SetString("lightgreen", "\x03");
            g_hChatColors.SetString("yellow", "\x04");
            g_hChatColors.SetString("green", "\x05");
        }
        case Engine_CSGO: {
            g_hChatColors.SetString("red", "\x07");
            g_hChatColors.SetString("lightred", "\x0F");
            g_hChatColors.SetString("darkred", "\x02");
            g_hChatColors.SetString("bluegrey", "\x0A");
            g_hChatColors.SetString("blue", "\x0B");
            g_hChatColors.SetString("darkblue", "\x0C");
            g_hChatColors.SetString("purple", "\x03");
            g_hChatColors.SetString("orchid", "\x0E");
            g_hChatColors.SetString("yellow", "\x09");
            g_hChatColors.SetString("gold", "\x10");
            g_hChatColors.SetString("lightgreen", "\x05");
            g_hChatColors.SetString("green", "\x04");
            g_hChatColors.SetString("lime", "\x06");
            g_hChatColors.SetString("grey", "\x08");
            g_hChatColors.SetString("grey2", "\x0D");
        }
        default: {
            g_hChatColors.SetString("lightgreen", "\x03");
            g_hChatColors.SetString("green", "\x04");
            g_hChatColors.SetString("olive", "\x05");
        }
    }

    g_hChatColors.SetString("engine 1", "\x01");
    g_hChatColors.SetString("engine 2", "\x02");
    g_hChatColors.SetString("engine 3", "\x03");
    g_hChatColors.SetString("engine 4", "\x04");
    g_hChatColors.SetString("engine 5", "\x05");
    g_hChatColors.SetString("engine 6", "\x06");
    g_hChatColors.SetString("engine 7", "\x07");
    g_hChatColors.SetString("engine 8", "\x08");
    g_hChatColors.SetString("engine 9", "\x09");
    g_hChatColors.SetString("engine 10", "\x0A");
    g_hChatColors.SetString("engine 11", "\x0B");
    g_hChatColors.SetString("engine 12", "\x0C");
    g_hChatColors.SetString("engine 13", "\x0D");
    g_hChatColors.SetString("engine 14", "\x0E");
    g_hChatColors.SetString("engine 15", "\x0F");
    g_hChatColors.SetString("engine 16", "\x10");
}

public any Native_CAddChatColor(Handle hPlugin, int nParams) {
    static char szName[32], szColor[32];
    GetNativeString(1, szName, sizeof(szName));
    GetNativeString(2, szColor, sizeof(szColor));
    return g_hChatColors.SetString(szName, szColor);
}

static void ProcessVariables(char[] szMessage, int nMaxLength, bool isColor = true, bool isVariable = false) {
    int iBufIndex = 0, i = 0, nNameLen = 0, iOldBufIndex = 0;
    char[] szBuffer = new char[nMaxLength];
    static char szName[32], szValue[128];
    ConVar hConVar;

    while (szMessage[i] && iBufIndex < nMaxLength - 1) {
        if (szMessage[i] != '{' || (nNameLen = FindCharInString(szMessage[i + 1], '}')) == -1) {
            szBuffer[iBufIndex++] = szMessage[i++];
            continue;
        }

        strcopy(szName, nNameLen + 1, szMessage[i + 1]);
        iOldBufIndex = iBufIndex;
        if (isVariable) {
            if (StrEqual(szName, "currentmap", false)) {
                GetCurrentMap(szValue, sizeof(szValue));
                GetMapDisplayName(szValue, szValue, sizeof(szValue));
                iBufIndex += strcopy(szBuffer[iBufIndex], nMaxLength - iBufIndex, szValue);
            }
            else if (StrEqual(szName, "nextmap", false)) {
                if (g_bMapChooser && EndOfMapVoteEnabled() && !HasEndOfMapVoteFinished()) {
                    iBufIndex += strcopy(szBuffer[iBufIndex], nMaxLength - iBufIndex, "Pending Vote");
                } else {
                    GetNextMap(szValue, sizeof(szValue));
                    GetMapDisplayName(szValue, szValue, sizeof(szValue));
                    iBufIndex += strcopy(szBuffer[iBufIndex], nMaxLength - iBufIndex, szValue);
                }
            }
            else if (StrEqual(szName, "date", false)) {
                FormatTime(szValue, sizeof(szValue), "%Y/%m/%d");
                iBufIndex += strcopy(szBuffer[iBufIndex], nMaxLength - iBufIndex, szValue);
            }
            else if (StrEqual(szName, "time", false)) {
                FormatTime(szValue, sizeof(szValue), "%I:%M:%S%p");
                iBufIndex += strcopy(szBuffer[iBufIndex], nMaxLength - iBufIndex, szValue);
            }
            else if (StrEqual(szName, "time24", false)) {
                FormatTime(szValue, sizeof(szValue), "%H:%M:%S");
                iBufIndex += strcopy(szBuffer[iBufIndex], nMaxLength - iBufIndex, szValue);
            }
            else if (StrEqual(szName, "timeleft", false)) {
                int mins, secs, timeleft;
                if (GetMapTimeLeft(timeleft) && timeleft > 0) {
                    mins = timeleft / 60;
                    secs = timeleft % 60;
                }

                iBufIndex += FormatEx(szBuffer[iBufIndex], nMaxLength - iBufIndex, "%d:%02d", mins, secs);
            }
            else if ((hConVar = FindConVar(szName))) {
                hConVar.GetString(szValue, sizeof(szValue));
                iBufIndex += strcopy(szBuffer[iBufIndex], nMaxLength - iBufIndex, szValue);
            }
        }
        if (iOldBufIndex == iBufIndex) {
            if (isColor) {
                if (szName[0] == '#') {
                    iBufIndex += FormatEx(szBuffer[iBufIndex], nMaxLength - iBufIndex, "%c%s", (nNameLen == 9) ? 8 : 7, szName[1]);
                }
                else if (g_hChatColors.GetString(szName, szValue, sizeof(szValue))) {
                    iBufIndex += strcopy(szBuffer[iBufIndex], nMaxLength - iBufIndex, szValue);
                }
                else {
                    iBufIndex += FormatEx(szBuffer[iBufIndex], nMaxLength - iBufIndex, "{%s}", szName);
                }
            }
            else {
                iBufIndex += FormatEx(szBuffer[iBufIndex], nMaxLength - iBufIndex, "{%s}", szName);
            }
        }
        
        i += nNameLen + 2;
    }

    szBuffer[iBufIndex] = '\0';
    strcopy(szMessage, nMaxLength, szBuffer);
}

public void RemoveVariables(char[] szMessage, int nMaxLength) {
    int iBufIndex = 0, i = 0, nNameLen = 0;
    char[] szBuffer = new char[nMaxLength];

    while (szMessage[i] && iBufIndex < nMaxLength - 1) {
        if (szMessage[i] != '{' || (nNameLen = FindCharInString(szMessage[i + 1], '}')) == -1) {
            szBuffer[iBufIndex++] = szMessage[i++];
            continue;
        }
        i += nNameLen + 2;
    }

    szBuffer[iBufIndex] = '\0';
    strcopy(szMessage, nMaxLength, szBuffer);
}

bool CalcRPN(ArrayStack RPNStack, ArrayList SymbolList, int& iRes, bool bNotFoundAsError=true) {
    ArrayStack ResStack = RPNStack.Clone();
    int aReverse[MAX_TOKEN_COUNT], nLen = 0;
    iRes = 0;
    while (!ResStack.Empty) {
        aReverse[nLen++] = ResStack.Pop();
    }
    for (int i = nLen - 1; i >= 0; i--) {
        if (aReverse[i] >= view_as<int>(AND)) {
            static any num1, num2;
            switch (view_as<OP>(aReverse[i])) {
                case AND: {
                    if (!Pop2(ResStack, num1, num2)) {
                        return false;
                    }
                    ResStack.Push(num2 && num1);
                }
                case OR: {
                    if (!Pop2(ResStack, num1, num2)) {
                        return false;
                    }
                    ResStack.Push(num2 || num1);
                }
                case NOT: {
                    if (!Pop1(ResStack, num1)) {
                        return false;
                    }
                    ResStack.Push(!num1);
                }
                case BAND: {
                    if (!Pop2(ResStack, num1, num2)) {
                        return false;
                    }
                    ResStack.Push(num2 & num1);
                }
                case BNOT: {
                    if (!Pop1(ResStack, num1)) {
                        return false;
                    }
                    ResStack.Push(~num1);
                }
                case BOR: {
                    if (!Pop2(ResStack, num1, num2)) {
                        return false;
                    }
                    ResStack.Push(num2 | num1);
                }
                case BXOR: {
                    if (!Pop2(ResStack, num1, num2)) {
                        return false;
                    }
                    ResStack.Push(num2 ^ num1);
                }
                case ADD: {
                    if (!Pop2(ResStack, num1, num2)) {
                        return false;
                    }
                    ResStack.Push(num2 + num1);
                }
                case SUB: {
                    if (!Pop2(ResStack, num1, num2)) {
                        return false;
                    }
                    ResStack.Push(num2 - num1);
                }
                case MULTI: {
                    if (!Pop2(ResStack, num1, num2)) {
                        return false;
                    }
                    ResStack.Push(num1 * num2);
                }
                case DIV: {
                    if (!Pop2(ResStack, num1, num2)) {
                        return false;
                    }
                    ResStack.Push(num2 / num1);
                }
                case MOD: {
                    if (!Pop2(ResStack, num1, num2)) {
                        return false;
                    }
                    ResStack.Push(num2 % num1);
                }
                case LT: {
                    if (!Pop2(ResStack, num1, num2)) {
                        return false;
                    }
                    ResStack.Push(num2 < num1);
                }
                case LE: {
                    if (!Pop2(ResStack, num1, num2)) {
                        return false;
                    }
                    ResStack.Push(num2 <= num1);
                }
                case EQ: {
                    if (!Pop2(ResStack, num1, num2)) {
                        return false;
                    }
                    ResStack.Push(num2 == num1);
                }
                case NE: {
                    if (!Pop2(ResStack, num1, num2)) {
                        return false;
                    }
                    ResStack.Push(num2 != num1);
                }
                case GE: {
                    if (!Pop2(ResStack, num1, num2)) {
                        return false;
                    }
                    ResStack.Push(num2 >= num1);
                }
                case GT: {
                    if (!Pop2(ResStack, num1, num2)) {
                        return false;
                    }
                    ResStack.Push(num2 > num1);
                }
                default: {
                    return false;
                }
            }
        }
        else {
            static char szToken[MAX_TOKEN_LENGTH];
            SymbolList.GetString(aReverse[i], szToken, sizeof(szToken));
            static float fToken;
            static ConVar hConVar;
            if (StringToFloatEx(szToken, fToken) > 0) {
                ResStack.Push(RoundFloat(fToken));
            } else {
                hConVar = FindConVar(szToken);
                if (IsValidHandle(hConVar)) {
                    ResStack.Push(hConVar.IntValue);
                    delete hConVar;
                }
                else if (bNotFoundAsError) {
                    return false;
                }
                else {
                    ResStack.Push(0);
                }
            }
        }
    }
    if (Pop1(ResStack, iRes) && ResStack.Empty) {
        return true;
    }
    return false;
}

stock bool Pop2(ArrayStack hStack, any& num1, any& num2) {
    if (hStack.Empty) {
        return false;
    }
    num1 = hStack.Pop();
    if (hStack.Empty) {
        return false;
    }
    num2 = hStack.Pop();
    return true;
}

stock bool Pop1(ArrayStack hStack, any& num1) {
    if (hStack.Empty) {
        return false;
    }
    num1 = hStack.Pop();
    return true;
}

bool ParseConditionsToRPN(const char[] szBuffer, ArrayStack RPNStack, ArrayList SymbolList) {
    int iNext = 0;
    bool bIsOP = false;
    OP op1;
    static char szToken[MAX_TOKEN_LENGTH];
    ArrayStack OPStack = new ArrayStack(1);

    RPNStack.Clear();
    for (int i = 0; szBuffer[i] != '\0'; i += iNext) {
        if (GetNextToken(szBuffer[i], szToken, sizeof(szToken), iNext, bIsOP, op1)) {
            if (bIsOP) {
                if (op1 == LP) {
                    OPStack.Push(op1);
                }
                else if (op1 == RP) {
                    static OP op2;
                    while (!OPStack.Empty && (op2 = OPStack.Pop()) != LP) {
                        RPNStack.Push(op2);
                    }
                    if (OPStack.Empty && op2 != LP) {
                        return false;
                    }
                }
                else {
                    static OP op2;
                    int pc1 = GetOPProcedence(op1), pc2;
                    while (!OPStack.Empty) {
                        op2 = OPStack.Pop();
                        pc2 = GetOPProcedence(op2);
                        if (op2 != LP && (pc1 > pc2 || GetOPAssociation(op1) == LeftAssoc && pc1 == pc2)) {
                            RPNStack.Push(op2);
                        }
                        else {
                            OPStack.Push(op2);
                            break;
                        }
                    }
                    OPStack.Push(op1);
                }
            }
            else {
                int iIdx;
                if ((iIdx = SymbolList.FindString(szToken)) == -1) {
                    iIdx = SymbolList.PushString(szToken);
                    
                }
                RPNStack.Push(iIdx);
            }
        }
    }
    while (!OPStack.Empty) {
        OP op = OPStack.Pop();
        RPNStack.Push(op);
    }
    return true;
}

enum OP {
    AND=256,
    OR,
    NOT,
    BAND,
    BNOT,
    BOR,
    BXOR,
    ADD,
    SUB,
    MULTI,
    DIV,
    MOD,
    LT,
    LE,
    EQ,
    NE,
    GE,
    GT,
    LP,
    RP,
    OP_NUM
}

char OPStart[] =        "^~!&|+-*/%()<>=";
char OPWideStart[] =    "&|<>=!";
char OPWideEnd[] =      "&|====";

stock bool GetNextToken(const char[] szBuffer, char[] szToken, int nMaxLength, int& iNext, bool &bIsOP, OP &op) {
    iNext = 0;
    bIsOP = false;
    int iTokenStart = 0, iIdx;

    for (iNext = 0; szBuffer[iNext] != '\0'; iNext++) {
        if (!IsCharSpace(szBuffer[iNext])){
            break;
        }
    }

    if (szBuffer[iNext] == '\0') {
        return false;
    }

    if (IsCharInString(szBuffer[iNext], OPStart) >= 0) {
        bIsOP = true;
        iTokenStart = iNext;
        if ((iIdx = IsCharInString(szBuffer[iNext], OPWideStart)) >= 0) {
            if (szBuffer[iNext+1] == OPWideEnd[iIdx]) {
                iNext++;
            }
        }
        iNext++;
        if (nMaxLength > iNext - iTokenStart + 1) {
            nMaxLength = iNext - iTokenStart + 1;
        }
        strcopy(szToken, nMaxLength, szBuffer[iTokenStart]);
        op = GetOPFromString(szToken);
    } else {
        bIsOP = false;
        iTokenStart = iNext;
        for (; szBuffer[iNext] != '\0'; iNext++) {
            if (IsCharSpace(szBuffer[iNext]) || IsCharInString(szBuffer[iNext], OPStart) >= 0) {
                break;
            }
        }
        if (nMaxLength > iNext - iTokenStart + 1) {
            nMaxLength = iNext - iTokenStart + 1;
        }
        strcopy(szToken, nMaxLength, szBuffer[iTokenStart]);
    }

    return true;
}

stock int GetOPProcedence(OP op) {
    switch (op) {
        case LP, RP: {
            return 1;
        }
        case BNOT, NOT: {
            return 2;
        }
        case MULTI,DIV, MOD: {
            return 3;
        }
        case ADD, SUB: {
            return 4;
        }
        case LE, GE, LT, GT: {
            return 5;
        }
        case EQ, NE: {
            return 6;
        }
        case BAND: {
            return 7;
        }
        case BXOR: {
            return 8;
        }
        case BOR: {
            return 9;
        }
        case AND: {
            return 10;
        }
        case OR: {
            return 11;
        }
    }
    return -1;
}

enum Assoc {
    LeftAssoc,
    RightAssoc
}

stock Assoc GetOPAssociation(OP op) {
    if (op == BNOT && op == NOT) {
        return RightAssoc;
    }
    return LeftAssoc;
}

stock OP GetOPFromString(const char[] szOP) {
    switch (szOP[0]) {
        case '(': {
            return LP;
        }
        case ')': {
            return RP;
        }
        case '~': {
            return BNOT;
        }
        case '^': {
            return BXOR;
        }
        case '+': {
            return ADD;
        }
        case '-': {
            return SUB;
        }
        case '*': {
            return MULTI;
        }
        case '/': {
            return DIV;
        }
        case '%': {
            return MOD;
        }
        case '<': {
            if (szOP[1] == '=') {
                return LE;
            } else {
                return LT;
            }
        }
        case '>': {
            if (szOP[1] == '=') {
                return GE;
            } else {
                return GT;
            }
        }
        case '=': {
            return EQ;
        }
        case '!': {
            if (szOP[1] == '=') {
                return NE;
            } else {
                return NOT;
            }
        }
        case '&': {
            if (szOP[1] == '&') {
                return AND;
            } else {
                return BAND;
            }
        }
        case '|': {
            if (szOP[1] == '|') {
                return OR;
            } else {
                return BOR;
            }
        }
    }
    return OP_NUM;
}

stock int IsCharInString(int ch, const char[] str) {
    for (int i = 0; str[i] != '\0'; i++) {
        if (str[i] == ch) {
            return i;
        }
    }
    return -1;
}

public any Native_ParseCondition(Handle hPlugin, int nParams) {
    int nMaxLength = GetNativeCell(2);
    char[] szMessage = new char[nMaxLength];
    GetNativeString(1, szMessage, nMaxLength);

    return ParseConditionsToRPN(szMessage,  GetNativeCell(3), GetNativeCell(4));
}

public any Native_CalcRPN(Handle hPlugin, int nParams) {
    int iRes = GetNativeCellRef(3);

    bool bTemp = CalcRPN(GetNativeCell(1), GetNativeCell(2), iRes, GetNativeCell(4));
    SetNativeCellRef(3, iRes);
    return bTemp;
}


public any Native_CRemoveVariables(Handle hPlugin, int nParams) {
    int nMaxLength = GetNativeCell(2);
    char[] szMessage = new char[nMaxLength];
    GetNativeString(1, szMessage, nMaxLength);

    RemoveVariables(szMessage, nMaxLength);
    return SetNativeString(1, szMessage, nMaxLength);
}

public any Native_CProcessVariables(Handle hPlugin, int nParams) {
    int nMaxLength = GetNativeCell(2);
    char[] szMessage = new char[nMaxLength];
    GetNativeString(1, szMessage, nMaxLength);

    ProcessVariables(szMessage, nMaxLength, GetNativeCell(3), GetNativeCell(4));
    return SetNativeString(1, szMessage, nMaxLength);
}

public any Native_CPrintToChat(Handle hPlugin, int nParams) {
    static char szMessage[MAX_MESSAGE_LEN];
    szMessage[0] = '\x01'; // Must have a szColor in beginning, or will have unexpected results

    int iClient = GetNativeCell(1), iAuthor = GetNativeCell(2);

    SetGlobalTransTarget(iClient);
    FormatNativeString(0, 3, 4, sizeof(szMessage) - 1, _, szMessage[1]);

    if (iClient < 1 || iClient > MaxClients) {
        ThrowError("Invalid client index %d", iClient);
    }

    if (!IsClientInGame(iClient)) {
        ThrowError("Client %d is not in game", iClient);
    }

    ProcessVariables(szMessage, sizeof(szMessage));

    if (0 < iAuthor <= MaxClients) {
        // LogMessage("%s sent to %d", szMessage, iClient);
        SayText2(iClient, iAuthor, szMessage, "", "");
    }
    else {
        PrintToChat(iClient, szMessage);
    }

    return SP_ERROR_NONE;
}

public any Native_CPrintToChatAll(Handle hPlugin, int nParams) {
    static char szMessage[MAX_MESSAGE_LEN];
    szMessage[0] = '\x01'; // Must have a szColor in beginning, or will have unexpected results

    int iAuthor = GetNativeCell(1);

    if (iAuthor != -1 && (iAuthor < 1 || iAuthor > MaxClients)) {
        iAuthor = 0;
    }

    for (int iClient = 1; iClient <= MaxClients; iClient++) {
        if (!IsClientInGame(iClient)) {
            continue;
        }

        SetGlobalTransTarget(iClient);
        FormatNativeString(0, 2, 3, sizeof(szMessage) - 1, _, szMessage[1]);
        ProcessVariables(szMessage, sizeof(szMessage));

        if (iAuthor == -1) {
            SayText2(iClient, iClient, szMessage, "", "");
        }
        else if (iAuthor == 0) {
            PrintToChat(iClient, szMessage);
        }
        else {
            SayText2(iClient, iAuthor, szMessage, "", "");
        }
    }

    return SP_ERROR_NONE;
}

/// When in Protobuf, only the szText can be sent, the other strings will be ignored.
static void SayText2(int iClient, int iAuthor, const char[] szFlags, const char[] szName, const char[] szText) {
    Handle hMsg = StartMessageOne("SayText2", iClient, USERMSG_RELIABLE|USERMSG_BLOCKHOOKS);
    if (g_bProtobuf) { 
        PbSetInt(hMsg, "ent_idx", iAuthor);
        PbSetBool(hMsg, "chat", true);
        PbSetString(hMsg, "msg_name", szText);
        PbAddString(hMsg, "params", "");
        PbAddString(hMsg, "params", "");
        PbAddString(hMsg, "params", "");
        PbAddString(hMsg, "params", "");
    }
    BfWriteByte(hMsg, iAuthor);
    BfWriteByte(hMsg, true);
    BfWriteString(hMsg, szFlags);
    BfWriteString(hMsg, szName);
    BfWriteString(hMsg, szText);
    EndMessage();
}

public any Native_CSayText2(Handle hPlugin, int nParams) {
    static char szFlags[MAX_SAYTEXT2_LEN], szName[MAX_SAYTEXT2_LEN], szText[MAX_SAYTEXT2_LEN];

    GetNativeString(3, szFlags, sizeof(szFlags));
    GetNativeString(4, szName, sizeof(szName));
    GetNativeString(5, szText, sizeof(szText));

    SayText2(GetNativeCell(1), GetNativeCell(2), szFlags, szName, szText);

    return SP_ERROR_NONE;
}

public any Native_CSayText2All(Handle hPlugin, int nParams) {
    static char szFlags[MAX_SAYTEXT2_LEN], szName[MAX_SAYTEXT2_LEN], szText[MAX_SAYTEXT2_LEN];
    int iAuthor = GetNativeCell(1);
    if (iAuthor < 1 || iAuthor > MaxClients) {
        iAuthor = -1;
    }

    GetNativeString(2, szFlags, sizeof(szFlags));
    GetNativeString(3, szName, sizeof(szName));
    GetNativeString(4, szText, sizeof(szText));

    for (int i = 1; i <= MaxClients; i++) {
        if (IsClientInGame(i)) {
            if (iAuthor == -1) {
                SayText2(i, i, szFlags, szName, szText);
            }
            else {
                SayText2(i, iAuthor, szFlags, szName, szText);
            }
        }
    }

    return SP_ERROR_NONE;
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max) {
    CreateNative("CAddChatColor", Native_CAddChatColor);
    CreateNative("CProcessVariables", Native_CProcessVariables);
    CreateNative("CRemoveVariables", Native_CRemoveVariables);
    CreateNative("CPrintToChat", Native_CPrintToChat);
    CreateNative("CPrintToChatAll", Native_CPrintToChatAll);
    CreateNative("CSayText2", Native_CSayText2);
    CreateNative("CSayText2All", Native_CSayText2All);
    CreateNative("ParseCondition", Native_ParseCondition);
    CreateNative("CalculateRPN", Native_CalcRPN);

    RegPluginLibrary("globalvariables");
    return APLRes_Success;
}

public void OnPluginStart() {
    delete g_hChatColors;
    g_hChatColors = new StringMap();
    AddChatColors();

    g_bMapChooser = LibraryExists("mapchooser");

    if (GetFeatureStatus(FeatureType_Native, "GetUserMessageType") == FeatureStatus_Available && GetUserMessageType() == UM_Protobuf) {
        g_bProtobuf = true;
    }
    else {
        g_bProtobuf = false;
    }
}

public void OnLibraryAdded(const char[] szName)
{
    if (StrEqual(szName, "mapchooser")) {
        g_bMapChooser = true;
    }
}

public void OnLibraryRemoved(const char[] szName)
{
    if (StrEqual(szName, "mapchooser")) {
        g_bMapChooser = false;
    }
}
