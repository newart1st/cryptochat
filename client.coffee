UtilsHelper =
  generatePassword: (len)->
    key = ''
    alphabet = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-!'
    for i in [1..len]
      key = key + alphabet[Math.ceil(Math.random()*alphabet.length)]
    return key

  storageGet: (key)->
    return $.jStorage.get(key)

  storageSet: (key,value)->
    $.jStorage.set(key,value)
    return true



class clientApp
  constructor: ()->
    openpgp.init()
    @socket = io.connect('http://localhost')
    @mainUser = new MainUser(@)
    @usersList = new UserList()
    @connected = ko.observable(false)
    @autorizationWord = ko.computed(
      =>
        word = ''
        if(@connected() && @mainUser.statusReady())
          if(!@mainUser.authorized())
            word = 'авторизуемся'
            @authorize()
          else
            word = 'авторивоаны'
        return word
    )
    @mainUser.name.subscribe(
        (newValue)=>
          if(!@updatingUserInfo())
            socket.emit('userCommand',{'name':'nameChanged','newName':newValue})

    )



    ###socket = io.connect('http://localhost')
    @user = new User
    privUniq = $.cookie('privUniq')
    @templateName = ko.observable('loading')
    reqObj = {}
    if privUniq
      reqObj.privateUniq = privUniq
    @onlineUsers = ko.observable(0)
    @memoryUsage = ko.observable(0)
    @updatingUserInfo = ko.observable(false)
    @memoryUsageWord = ko.computed(
      =>
        mem = @memoryUsage()
        kb = Math.floor(mem / 1024)
        return @formatDigit(kb) + ' kb'
    )

    socket.on(
      'userInfo',
      (data)=>
        if @user.privUniq != data.privUniq
          @user.privUniq = data.privUniq
          $.cookie('privUniq',@user.privUniq,{expires:7,path:'/'})
        @user.pubUniq = data.pubUniq
        @updatingUserInfo(true)
        @user.name(data.name)
        #@user.status(data.status)
        @templateName('loaded')
        @updatingUserInfo(false)
    )
    socket.on(
      'userUpdate',
      (data)=>
        @updatingUserInfo(true)
        @user[data.paramName](data.newValue)
        @updatingUserInfo(false)
    )
    @user.name.subscribe(
      (newValue)=>
        if(!@updatingUserInfo())
          socket.emit('userCommand',{'name':'nameChanged','newName':newValue})

    )
    @user.status.subscribe(
      (newValue)=>
        switch newValue
          when 1 then jonToServ()

    )
    socket.emit('init',reqObj)

    socket.on(
      'users',
      (data)=>
        if(data.onlineCount)
          @onlineUsers(data.onlineCount)
        console.log(data)
    )
    socket.on(
      'systemInfo',
      (data)=>
        if(data.memory)
          @memoryUsage(data.memory)
    )###
  joinToServ: =>
    console.log('need join to serv')
    console.log('need join to serv')

  fillServInfo: =>
    console.log('need join to serv')
    console.log('need join to serv')

  authorize: =>

  unauthorize: =>
    @socket.emit('unauthorize',true)

  formatDigit: (price) ->
    intPrice = parseInt(price)
    strPrice = intPrice.toString()
    ret = ""
    j = 0
    for i in [(strPrice.length-1)..0]
      if j != 0 && j % 3 == 0
        ret = ' ' + ret
      ret = strPrice[i] + ret
      j++
    return ret

  afterRender: ()=>
    console.log('main div rendered')

class UserList
  constructor: ()->
    @users = ko.observableArray([])
    @usersMap = {}
    @usersIdents = UtilsHelper.storageGet('UsersList')
    for md5ident in @usersIdents
      ##user = new User(@)
      userData = UtilsHelper.storageGet('user_'+md5ident)
      if(userData)
        @usersMap[md5ident] = new User(@)
        @usersMap[md5ident].md5ident(md5ident)
        @usersMap[md5ident].pubKeyStr(userData.pubKeyStr)
        @usersMap[md5ident].name(userData.pubKeyStr)
        @usersMap[md5ident].queueMassages = userData.queueMassages
        @users.push(@usersMap[md5ident])

  addUser: (user)=>
    md5ident = user.md5ident()
    if !@usersMap[md5ident]
      @usersMap[md5ident] = user
      @users.push(@usersMap[md5ident])

  changeStatus: (md5ident,status)=>
    if @usersMap[md5ident]
      @usersMap[md5ident].status(status)


class User
  constructor: (@userList)->
    @name = ko.observable('')
    @pubKeyStr = ko.observable('')
    @md5ident = ko.observable('')
    @status = ko.observable('offline')
    @pubKey = ko.observable(null)
    @queueMassages = []


class MainUser
  constructor: (@app)->
    @name = ko.observable('')
    @name(UtilsHelper.storageGet('username'))
    @statusReady = ko.observable(false)
    @md5ident = ko.observable('')
    @authorized = ko.observable(false)
    @name.subscribe(
      (newValue)=>
        @statusReady(false)
        @authorized(false)
        @app.unauthorize()
        if(newValue)
          @generateKeys()
    )
    if(@name())
      needGenerate = true
      @pass = UtilsHelper.storageGet('mainpass')
      @pubKeyStr = UtilsHelper.storageGet('mainPubKey')
      privKey = UtilsHelper.storageGet('mainPrivKey')
      if(pubKey && privKey)
        @pubKey = openpgp.read_publicKey(@pubKeyStr)
        if(!(@pubKey < 1))
          @privKey = openpgp.read_privateKey(privKey)
          if(!(@privKey.length < 1))
            needGenerate = false
            @statusReady(true)
            @md5ident(md5(@pubKeyStr))
      if(needGenerate)
        @generateKeys()

  generateKeys: ()=>
    @pass = generatePassword((15 + Math.floor(Math.random()*5) ))
    keyPair = openpgp.generate_key_pair(1, 2048, @name, @pass)
    @pubKeyStr = keyPair.publicKeyArmored
    UtilsHelper.storageSet('mainPubKey',@pubKeyStr)
    UtilsHelper.storageSet('mainPrivKey',keyPair.publicKeyArmored)
    @privKey = keyPair.privateKey
    @pubKey = openpgp.read_publicKey(keyPair.publicKeyArmored)
    @statusReady(true)
    @md5ident(md5(@pubKeyStr))



cApp = new clientApp()

$(document).ready(
  ->
    ko.applyBindings(cApp);
)
