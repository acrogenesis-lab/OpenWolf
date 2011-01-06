# -*- coding: utf-8 -*-
class Solicitud < ActiveRecord::Base  
  ORIGEN_DEFAULT = 1
  ORIGEN_PORTAL = 2
  ORIGEN_MIGRACION = 3
  
  VIA_DEFAULT = 1
  TIPO_INFORMACION = 1
  TIPO_DENUNCIA = 2
  ESTADO_NORMAL = 1
  ESTADO_ENTREGADA = 3
  ESTADO_NOENTREGADA = false
  ESTADO_NOASIGNADA = false
  ESTADO_COMPLETADA = true
  ESTADO_NOCOMPLETADA = false
  TIEMPOS = [["Todos", "ALL"],
             ["10 dias", "10"],
             ["7 a 9 dias", "7a9"],
             ["4 a 6 dias", "4a6"],
             ["0 a 3 dias", "0a3"],
             ["Atrasadas", "LATE"]]

  attr_accessor :dont_send_email

  #####################
  # Modulos y Plugins
  #####################
  
  versioned
  
#  acts_as_solr :fields => [:codigo, :solicitante_nombre,
  #  :textosolicitud, :observaciones, :fecha_creacion]

  #######################
  # Configuracion Solr
  ######################

  searchable do
    text :codigo
    text :solicitante_nombre
    text :textosolicitud, :default_boost => 2
    text :observaciones
    date :fecha_creacion
    time :created_at
    # integer :institucion_id, :references => Institucion
    # integer :municipio_id, :references => Municipio
    # integer :departamento_id, :references => Departamento
    # integer :via_id, :references => Via
    # integer :estado_id, :references => Estado
    # integer :clasificacion_id, :references => Clasificacion
    # integer :documentoclasificacion_id, :references => Documentoclasificacion
  end

  ##################
  # Callbacks
  # http://apidock.com/rails/v2.3.8/ActiveRecord/Callback
  ##################
  
  before_validation :cleanup
  before_validation(:on => :create) do
    completar_informacion
  end
  after_create :notificar_creacion

  #################
  # Relaciones
  #################

  
  belongs_to :institucion
  belongs_to :usuario
  belongs_to :municipio
  belongs_to :departamento
  belongs_to :via
  belongs_to :estado
  belongs_to :profesion
  belongs_to :genero
  belongs_to :rangoedad
  belongs_to :clasificacion
  belongs_to :motivonegativa
  belongs_to :motivoprorroga
  belongs_to :documentoclasificacion

  has_many :actividades, :dependent => :destroy
  has_many :adjuntos, :as => :proceso, :dependent => :destroy
  has_many :resoluciones, :dependent => :destroy
  has_many :recursosrevision, :dependent => :destroy

  has_many :enlaces, :through => :actividades, :uniq => true, :source => :usuario

  #######################
  # Validaciones
  ######################  
  
  validates_presence_of :fecha_creacion, :solicitante_nombre, :textosolicitud, :institucion_id
  
  validates_presence_of :email, :if => Proc.new{ |s| (s.origen_id == ORIGEN_PORTAL ? true : false) }
  validates_format_of :email, :with => /\A([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})\Z/i, :unless => Proc.new{ |s| s.email.nil? or s.email.empty? }
  validates_associated :institucion
  
  ########################
  # Filtros
  ########################
  default_scope :include => [:usuario, :institucion, :via, :estado]
  
  scope :asignadas, :conditions=>["solicitudes.asignada = ?", true ]
  scope :noasignadas, :conditions=>["solicitudes.asignada = ?", false ]

  scope :completadas, :conditions=>["solicitudes.fecha_completada is not null"]
  scope :nocompletadas, :conditions=>["solicitudes.fecha_completada is null"]

  scope :sinresolucion, :conditions=>["solicitudes.fecha_resolucion is null" ]
  scope :conresolucion, :conditions=>["solicitudes.fecha_resolucion is not null" ]
  scope :noentregadas, :conditions=>["solicitudes.fecha_entregada is null" ]

  scope :recientes, :order => "fecha_creacion desc"


  scope :tiempoejecucion, lambda { |tiempo_desde, tiempo_hasta| {
      :conditions => ["(((fecha_programada - ?)*100)/10) between ? and ?",Date.today, tiempo_desde, tiempo_hasta]
    }}

  scope :tiempo_transcurrido, lambda { |tiempo_desde, tiempo_hasta| {
      :conditions => ["(current_date - fecha_creacion) between ? and ?",tiempo_desde, tiempo_hasta]
    }}

  scope :tiempo_restante, lambda { |tiempo_desde, tiempo_hasta| {
      :conditions => ["(fecha_programada - current_date) between ? and ?",tiempo_desde, tiempo_hasta]
    }}


  ################################
  # Metodos de Instancia Publicos
  ###############################

  def es_pertinente?(u)
    l_ok = false

    #verficamos si es miembro de la unidad de informacion
    # de la institucion a la cual pertenece la solicitud
    if u.institucion_id == self.institucion_id
      if u.has_role?(:superudip) or u.has_role?(:userudip)
        l_ok = true
      end    
    end

    #verificamos si el usuario es un enlace asignado a esta solicitud
    if l_ok == false
      if self.actividades.count(:conditions => ["usuario_id = ?", u.id]) > 0
        l_ok = true
      end
    end

    return l_ok
  end

  def razon_negativa
    negativa = self.resoluciones.negativas.last
    if negativa.nil?
      return ''
    else
      negativa.descripcion
    end
  end

  def razon_ampliacion
    ampliacion = self.resoluciones.prorrogas.last
    if ampliacion.nil?
      return ''
    else
      ampliacion.descripcion
    end
  end

  def razon_resolucion
    r = self.resoluciones.last
    if r.nil?
      c_razon = ''
    else
      c_razon = r.descripcion
    end
    return c_razon
  end

  def tipo_resolucion(r = nil)
    r = self.resoluciones.last if r.nil?
    if r.nil?
      c_razon = ''
    else
      c_razon = r.tiporesolucion.nombre
    end
    return c_razon
  end

  def hay_prorroga
    cnt = self.resoluciones.prorrogas.count
    return (cnt > 0 ? 'Si' : 'No')
  end

  def razon_prorroga
    p = self.resoluciones.prorrogas.last
    razon = p.nil? ? '' : p.descripcion
    return razon
  end

  def fecha_notificacion_prorroga
    p = self.resoluciones.prorrogas.last
    fecha = p.nil? ? '' : p.created_at.to_date
    return fecha
  end
  
  def hay_revision
    cnt = self.recursosrevision.count
    return (cnt > 0 ? 'Si' : 'No')
  end

  def fecha_revision
    r = self.recursosrevision.last
    fecha = r.nil? ? '' : r.fecha_presentacion
    return fecha
  end

  def fecha_notificacion_revision
    r = self.recursosrevision.last
    fecha = r.nil? ? '' : r.fecha_notificacion
    return fecha
  end

  def fecha_ultima_resolucion
    r = self.resoluciones.last
    fecha = r.nil? ? '' : r.created_at.to_date
    return fecha
  end

  def tiempo_ampliacion
    i_tiempo = 0

    unless self.fecha_prorroga.nil?
      i_tiempo = (self.fecha_prorroga - (self.fecha_creacion + 10))
    end
    
    return i_tiempo
  end
  
  def tiempo_respuesta
    i_tiempo = 0

    if self.fecha_completada.nil?
      i_tiempo = (Date.today - self.fecha_creacion)
    else
      i_tiempo = (self.fecha_completada - self.fecha_creacion)
    end
    
    return i_tiempo
  end

  #regresa un array con informacion
  #usado en reportes o para exportar data
  def to_item
    resolucion = self.resoluciones.last
    revision = self.recursosrevision.last
    prorroga = self.resoluciones.prorrogas.last
    
    return [self.codigo,
            self.textosolicitud,
            self.fecha_creacion,
            self.via.nombre,
            self.tipo_resolucion(resolucion)]
  end

  def texto_solicitud(user = nil)
    c_texto = self.textosolicitud
    if self.informacion_publica == false
      if user.nil? or !user.has_role?(:superudip)
        c_texto ='Información no es pública'
      end
    end
    return c_texto
  end
  
  def extracto(user = nil)
    c_texto = self.textosolicitud[0..100] + '...'
    if self.informacion_publica == false
      if user.nil? or !user.has_role?(:superudip)
        c_texto ='Información no es pública'     
      end
    end
    return c_texto
  end
  
  def estado_actual
    return estado.nombre
  end

  def asignada?
    return (self.asignada == true)
  end
  
  def atrasada?
    l_ok = false
    unless terminada? or entregada?
      if dias_restantes < 0
        l_ok = true
      end
    end
    return l_ok
  end
  
  def terminada?
    return (not self.fecha_completada.nil?)
  end

  def entregada?
    return (not self.fecha_entregada.nil?)
  end

  def avance
    n_avance = 0.00
    if terminada?
      n_avance = 100.00
    else
      i_actividades = self.actividades.count
      unless i_actividades == 0
        i_completadas = self.actividades.completadas.count
        n_avance = ((i_completadas * 100)/i_actividades).to_f
      else
        n_avance = 0.00
      end
    end
    return n_avance
  end
  
  def dias_restantes
    dias = (fecha_programada - Date.today)
    if dias <= 0 or self.terminada?
      dias = 0
    end
    return dias
  end

  def actualizar_asignaciones
    self.asignada = (self.actividades.count > 0)
    self.save!
  end

  #actualiza el estado de la solicitud segun el estado de sus
  #actividades
  def actividad_terminada(fecha = Date.today)
    l_ok = true
    if self.actividades.count == self.actividades.completadas.count
      self.fecha_completada = fecha
      l_ok = self.save
    end
    return l_ok
  end

  #actualiza el estado a Entregada a Solicitante
  def solicitud_entregada(date = Date.today)
    self.fecha_entregada = date
    self.estado_id = ESTADO_ENTREGADA
    self.save!
  end

  #retorna un arreglo con los correos electronicos
  # de las personas relacionadas a la notificacion
  def correos_interesados
    correos = []

    #usuarios unidad informacion
    usuarios_udip = self.institucion.usuarios.udip
    usuarios_udip.each { |u|
      correos << u.email unless u.email.empty?
    }
    
    #ciudadano si hay correo
    unless self.email.empty?
      correos << self.email
    end

    #enlaces
    self.enlaces.each { |e|
      correos << e.email unless e.email.empty?
    }
    
    return correos
  end

  ################################
  # Metodos de Instancia Privados
  # http://apidock.com/ruby/Module/private
  ################################
  
  private

  def completar_informacion
    #validamos el origen de la solicitud
    # y determinamos institucion y usuario a utilizar

    logger.debug { "Completando Info" }
    if self.origen_id == ORIGEN_DEFAULT
      # usa current_user para obtenerlo
      logger.debug { "Origen default" }
      self.institucion_id = self.usuario.institucion_id      
    elsif self.origen_id == ORIGEN_PORTAL
      #si el orgen es el portal no hay usuario
      # asi que usamos el usuario de tipo ciudadano
      logger.debug { "Origen portal" }

      ciudadano = self.institucion.usuarios.ciudadanos.first      
      self.usuario_id = ciudadano.id
      
      logger.debug { "Usuario: #{self.usuario_id}" }
    else
      logger.debug { "Origen migracion" }
      superudip = self.institucion.usuarios.supervisores.first
      self.usuario_id = superudip.id
    end

    logger.debug { "Ins: #{self.institucion_id}" }
    
    unless self.institucion.nil?

      if self.origen_id != ORIGEN_MIGRACION        
        self.fecha_creacion = Date.today if self.fecha_creacion.nil?
        self.fecha_programada = fecha_creacion + 10
        self.departamento_id = municipio.departamento_id unless municipio.nil?
        self.estado_id = ESTADO_NORMAL
        self.asignada = false      
        self.solicitante_identificacion = 'No Disponible'        
      end

      self.tiposolicitud_id = TIPO_INFORMACION
      self.documentoclasificacion_id = Documentoclasificacion.find_by_codigo(Documentoclasificacion::SOLICITUDINFOPUBLICA).id
      self.numero = Solicitud.maximum(:numero, :conditions => ["solicitudes.institucion_id = ? and solicitudes.ano = ?",self.institucion_id, self.ano]).to_i + 1               
      self.codigo = institucion.codigo + '-'+Documentoclasificacion::SOLICITUDINFOPUBLICA+'-' +  self.ano.to_s + '-' + self.numero.to_s.rjust(6,'0')
      self.forma_entrega = 'No Disponible'        
      self.ano = self.fecha_creacion.year
      
    end

    logger.debug { "Before save: #{self.inspect}" }
    
  end

  def notificar_creacion
    Notificaciones.deliver_nueva_solicitud(self) unless (self.dont_send_email == true)
  end

  #limpia la informacion de la solicitud
  def cleanup
    self.solicitante_nombre = self.solicitante_nombre.slice(0..254)
  end
  
end