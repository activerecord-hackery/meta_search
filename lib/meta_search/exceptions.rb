module MetaSearch
  # Raised when type casting for a column fails.
  class TypeCastError < StandardError; end

  # Raised if you don't return a relation from a custom search method.
  class NonRelationReturnedError < StandardError; end

  # Raised if you try to access a relation that's joining too many tables to itself.
  # This is designed to prevent a malicious user from accessing something like
  # :developers_company_developers_company_developers_company_developers_company_...,
  # resulting in a query that could cause issues for your database server.
  class JoinDepthError < StandardError; end

  # Raised if you try to search on a polymorphic belongs_to association without specifying
  # its type.
  class PolymorphicAssociationMissingTypeError < StandardError; end
end