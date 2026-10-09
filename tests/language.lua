local Language,B,texts = ...
local checks=0
local function check(value,message) assert(value,message);checks=checks+1 end
local keys={'mod','label','description','seeker_label','seeker_description','multiplayer_label','multiplayer_description'}
local count=0
for locale,catalog in pairs(texts) do
    count=count+1
    check(Language.resolve(locale)==locale,'canonical locale resolves to itself')
    for _,key in ipairs(keys) do
        check(type(catalog[key])=='string' and #catalog[key]>0,'all seven option fields translated')
    end
end
check(count==14,'single catalog includes fourteen locales')
for code,locale in pairs(Language.codes) do
    check(texts[locale] and Language.resolve(code:upper():gsub('-','_'))==locale,'aliases handle case and underscores')
end
for _,code in ipairs({'','unsupported','xx-YY','KO invalid','english'}) do
    check(Language.resolve(code)=='en','unknown language defaults to English')
end
check(Language.resolve(nil)=='en' and Language.resolve(false)=='en' and Language.resolve(4)=='en','invalid code types fall back')
local function ptr(value) return B.u32(value%4294967296)..B.u32(math.floor(value/4294967296)) end
local function fixture()
    local channel={base=0x10000000,code='KR',index=0,reads={},overrides={}}
    function channel:read(at,size)
        self.reads[#self.reads+1]={at,size}
        if self.fail then error('unavailable') end
        if self.overrides[at]~=nil then return self.overrides[at] end
        if at==self.base+0x3326340 then return ptr(0x70000000) end
        if at==0x70000000+705712 then return B.u32(self.index) end
        if at==self.base+0x37C5650+self.index*8 then return ptr(0x71000000) end
        if at==0x71000000+8 then return ptr(0x72000000) end
        if at==0x72000000 then
            if size==16 and self.throw16 then error('16_byte_read_unavailable') end
            if size==16 and self.no16 then return nil end
            return (self.code..string.rep('\0',size)):sub(1,size)
        end
    end
    return Language.new(channel,B,texts),channel
end
local language,channel=fixture()
check(language.current=='en' and language:text('label')==texts.en.label,'before first poll labels are English')
language:poll(0)
check(language.current=='ko' and #channel.reads==5,'one bounded read sequence selects Korean')
local before=#channel.reads
channel.code='FR'
for i=1,24 do language:poll(i/100) end
for _=1,1000 do language:text('mod');language:text('label');language:text('description') end
check(language.current=='ko' and #channel.reads==before,'polls and label callbacks are throttled')
language:poll(0.25)
check(language.current=='fr' and language:text('label')==texts.fr.label,'language changes at next scheduled poll')
channel.code='KR';language:poll(0.5)
check(language.current=='ko','French-to-Korean round trip succeeds')
before=#channel.reads
for _,now in ipairs({-1,0/0,math.huge,'0'}) do language:poll(now) end
language:poll(nil)
check(#channel.reads==before and language.current=='ko','invalid timestamps do not read or alter language')
channel.code='JP';language:poll(0)
check(language.current=='ja' and #channel.reads==before+5,'clock rewind refreshes immediately')
for _,code in ipairs({'US','UK','FR','IT','DE','ES','MX','JP','KR','BR','PT','PL','RU','CN','TW'}) do
    language,channel=fixture();channel.code=code;language:poll(0)
    check(language.current==Language.resolve(code),'all fifteen game record codes resolve')
    check(language:text('description')==texts[language.current].description,'descriptions use the same selected locale')
end
for index=0,14 do
    language,channel=fixture();channel.index=index;language:poll(0)
    check(language.current=='ko' and channel.reads[3][1]==channel.base+0x37C5650+index*8,
        'record selected by actual index, not a guessed index-language table')
end
for _,index in ipairs({15,16,4294967295}) do
    language,channel=fixture();channel.index=index;language:poll(0)
    check(language.current=='en' and #channel.reads==2,'invalid index never follows a record pointer')
end
for _,at in ipairs({0x10000000+0x3326340,0x71000000+8,0x10000000+0x37C5650}) do
    for _,value in ipairs({0,65535,140737488355328}) do
        language,channel=fixture();channel.overrides[at]=ptr(value);language:poll(0)
        check(language.current=='en','invalid pointers fall back before following memory')
    end
    for _,bytes in ipairs({'',string.rep('\0',7),string.rep('\0',9),false,123}) do
        language,channel=fixture();channel.overrides[at]=bytes;language:poll(0)
        check(language.current=='en','partial, oversized or invalid pointer reads refused')
    end
end
for _,bytes in ipairs({'',string.rep('\0',3),string.rep('\0',5),false,123}) do
    language,channel=fixture();channel.overrides[0x70000000+705712]=bytes;language:poll(0)
    check(language.current=='en' and #channel.reads==2,'index reads must be exactly four bytes')
end
for _,code in ipairs({'','unknown','KR invalid','123','KoreanLanguageLongerThanLimit','KO-xxxxxxxxxx'}) do
    language,channel=fixture();channel.code=code;language:poll(0)
    check(language.current=='en','malformed or unsupported record text falls back')
end
for _,flag in ipairs({'no16','throw16'}) do
    language,channel=fixture();channel[flag]=true;language:poll(0)
    check(language.current=='ko' and #channel.reads==6 and channel.reads[6][2]==8,
        'eight-byte fallback handles unavailable sixteen-byte reads')
end
language,channel=fixture();language:poll(0);channel.fail=true;language:poll(0.25)
check(language.current=='en','failed memory reads restore safe English display')
channel.fail=false;language:poll(0.5)
check(language.current=='ko','temporary read failures do not block later recovery')
language=Language.new({},B,texts);language:poll(0)
check(language:text('label')==texts.en.label,'missing channel fields never propagate errors to control loop')
language,channel=fixture()
local incomplete={en=texts.en,ko={mod=texts.ko.mod}}
language=Language.new(channel,B,incomplete);language:poll(0)
check(language:text('mod')==texts.ko.mod and language:text('label')==texts.en.label,
    'individual missing translations use English without losing other localized fields')
channel.code='FR';language:poll(0.25)
check(language.current=='en','missing locale table falls back entirely')
return checks
