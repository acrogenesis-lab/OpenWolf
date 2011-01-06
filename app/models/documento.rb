class Documento < ActiveRecord::Base
  versioned
  acts_as_nested_set
  
  ORIGEN_INTERNO = 1
  ORIGEN_EXTERNO = 2
  ORIGENES = [["Interno", ORIGEN_INTERNO], ["Externo", ORIGEN_EXTERNO]]
  ESTADO_BORRADOR = 1
  ESTADO_ENVIADO = 2
  ESTADOS = [["Borrador",ESTADO_BORRADOR], ["Enviado", ESTADO_ENVIADO]]
  ORIGINAL = 1
  COPIA = 0
  
  before_validation(:on => :create) do
    completar_informacion
  end
  
  belongs_to :institucion
  belongs_to :documentocategoria
  belongs_to :documentoclasificacion
  belongs_to :autor, :class_name => "Usuario", :foreign_key => :autor_id
  belongs_to :usuario
  belongs_to :institucion

  has_many :documentodestinatarios, :dependent => :destroy

  validates_presence_of :numero, :fecha_documento, :asunto, :texto
  validates_uniqueness_of :numero

#  acts_as_solr :fields => [:numero, :clasificacion_nombre,
#  :categoria_nombre, :fecha_documento, :autor_datos, :asunto, :texto,
#  :fecha_recepcion, :remitente_nombre, :remitente_direccion,
  #  :remitente_telefonos, :remitente_email, :institucion_nombre]

   #######################
  # Configuracion Solr
  ######################

  searchable do
    text :numero
    text :clasificacion_nombre
    text :categoria_nombre
    date :fecha_documento
    text :autor_datos
    text :asunto
    text :texto
    date :fecha_recepcion
    text :remitente_nombre
    text :remitente_direccion
    text :remitente_telefonos
    text :remitente_email
    text :institucion_nombre
    time :created_at
  end

  default_scope :include => [:documentoclasificacion, :documentocategoria, :autor, :usuario, :institucion]
  
  def clasificacion_nombre
    self.documentoclasificacion.nombre
  end

  def categoria_nombre
    self.documentocategoria.nombre
  end

  def autor_datos
    self.autor.nombre + ', ' + self.autor.cargo + ', ' + self.autor.institucion.nombre
  end

  def autor_nombre
    self.autor.nombre + ', ' + self.autor.cargo
  end

  def institucion_nombre
    self.institucion.nombre
  end

  def origen_nombre
    return 'Interno' if self.origen_id == ORIGEN_INTERNO
    return 'Externo'
  end

  def estado_nombre
    return 'Borrador' if self.estado_envio_id == ESTADO_BORRADOR
    return 'Enviado' if self.estado_envio_id == ESTADO_ENVIADO
  end

  
  private

  def completar_informacion
    #asignar categoria
    self.documentocategoria_id = self.documentoclasificacion.documentocategoria_id

    #asignar institucion
    self.institucion_id = self.usuario.institucion_id

    #estado de envio
    self.estado_envio_id = ESTADO_BORRADOR

    #tipo de copia
    self.original = ORIGINAL
    
    #asignamos numero a documento si este es interno
    if generar_numero?
      
      codigo = self.documentoclasificacion.codigo
      
      i = Documento.count(:conditions => ["documentos.institucion_id = ? and date_part(\'year\',documentos.created_at) = ?", self.institucion_id, Date.today.year ] ).to_i + 1    
      self.numero = self.institucion.codigo + '-'+ codigo + '-' +  Date.today.year.to_s + '-' + i.to_s.rjust(6,'0')
      
    end

    
  end

  def generar_numero?
    l_generar = false

    if (self.origen_id == ORIGEN_INTERNO) || (self.origen_id == ORIGEN_EXTERNO and self.numero.empty?)
      l_generar = true
    end
    
    return l_generar
  end
  
end