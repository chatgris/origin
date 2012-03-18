# encoding: utf-8
module Origin

  # The optional module includes all behaviour that has to do with extra
  # options surrounding queries, like skip, limit, sorting, etc.
  module Optional
    extend Macroable

    # @attribute [rw] options The query options.
    attr_accessor :options

    # Add ascending sorting options for all the provided fields.
    #
    # @example Add ascending sorting.
    #   optional.ascending(:first_name, :last_name)
    #
    # @param [ Array<Symbol> ] fields The fields to sort.
    #
    # @return [ Optional ] The cloned optional.
    #
    # @since 1.0.0
    def ascending(*fields)
      sort_with_list(*fields, 1)
    end
    alias :asc :ascending
    key :asc, 1
    key :ascending, 1

    # Adds the option for telling MongoDB how many documents to retrieve in
    # it's batching.
    #
    # @example Apply the batch size options.
    #   optional.batch_size(500)
    #
    # @param [ Integer ] value The batch size.
    #
    # @return [ Optional ] The cloned optional.
    #
    # @since 1.0.0
    def batch_size(value = nil)
      option(value) { |options| options.store(:batch_size, value) }
    end

    # Add descending sorting options for all the provided fields.
    #
    # @example Add descending sorting.
    #   optional.descending(:first_name, :last_name)
    #
    # @param [ Array<Symbol> ] fields The fields to sort.
    #
    # @return [ Optional ] The cloned optional.
    #
    # @since 1.0.0
    def descending(*fields)
      sort_with_list(*fields, -1)
    end
    alias :desc :descending
    key :desc, -1
    key :descending, -1

    # Add the number of documents to limit in the returned results.
    #
    # @example Limit the number of returned documents.
    #   optional.limit(20)
    #
    # @param [ Integer ] value The number of documents to return.
    #
    # @return [ Optional ] The cloned optional.
    #
    # @since 1.0.0
    def limit(value = nil)
      option(value) { |options| options.store(:limit, value.to_i) }
    end

    # Adds the option to limit the number of documents scanned in the
    # collection.
    #
    # @example Add the max scan limit.
    #   optional.max_scan(1000)
    #
    # @param [ Integer ] value The max number of documents to scan.
    #
    # @return [ Optional ] The cloned optional.
    #
    # @since 1.0.0
    def max_scan(value = nil)
      option(value) { |options| options.store(:max_scan, value) }
    end

    # Tell the query not to timeout.
    #
    # @example Tell the query not to timeout.
    #   optional.no_timeout
    #
    # @return [ Optional ] The cloned optional.
    #
    # @since 1.0.0
    def no_timeout
      clone.tap { |query| query.options.store(:timeout, false) }
    end

    # Limits the results to only contain the fields provided.
    #
    # @example Limit the results to the provided fields.
    #   optional.only(:name, :dob)
    #
    # @param [ Array<Symbol> ] args The fields to return.
    #
    # @return [ Optional ] The cloned optional.
    #
    # @since 1.0.0
    def only(*args)
      option(*args) do |options|
        options.store(
          :fields, args.inject({}){ |sub, field| sub.tap { sub[field] = 1 }}
        )
      end
    end

    # Adds sorting criterion to the options.
    #
    # @example Add sorting options via a hash with integer directions.
    #   optional.order_by(name: 1, dob: -1)
    #
    # @example Add sorting options via a hash with symbol directions.
    #   optional.order_by(name: :asc, dob: :desc)
    #
    # @example Add sorting options via a hash with string directions.
    #   optional.order_by(name: "asc", dob: "desc")
    #
    # @example Add sorting options via an array with integer directions.
    #   optional.order_by([[ name, 1 ], [ dob, -1 ]])
    #
    # @example Add sorting options via an array with symbol directions.
    #   optional.order_by([[ name, :asc ], [ dob, :desc ]])
    #
    # @example Add sorting options via an array with string directions.
    #   optional.order_by([[ name, "asc" ], [ dob, "desc" ]])
    #
    # @example Add sorting options with keys.
    #   optional.order_by(:name.asc, :dob.desc)
    #
    # @example Add sorting options via a string.
    #   optional.order_by("name ASC, dob DESC")
    #
    # @param [ Array, Hash, String ] spec The sorting specification.
    #
    # @return [ Optional ] The cloned optional.
    #
    # @since 1.0.0
    def order_by(*spec)
      option(spec) do |options|
        spec.compact.each do |criterion|
          criterion.__sort_option__.each_pair do |field, direction|
            add_sort_option(options, field, direction)
          end
        end
      end
    end

    # Add the number of documents to skip.
    #
    # @example Add the number to skip.
    #   optional.skip(100)
    #
    # @param [ Integer ] value The number to skip.
    #
    # @return [ Optional ] The cloned optional.
    #
    # @since 1.0.0
    def skip(value = nil)
      option(value) { |options| options.store(:skip, value.to_i) }
    end

    # Limit the returned results via slicing embedded arrays.
    #
    # @example Slice the returned results.
    #   optional.slice(aliases: [ 0, 5 ])
    #
    # @param [ Hash ] criterion The slice options.
    #
    # @return [ Optional ] The cloned optional.
    #
    # @since 1.0.0
    def slice(criterion = nil)
      option(criterion) do |options|
        options.__union__(
          fields: criterion.inject({}) do |option, (field, val)|
            option.tap { |opt| opt.store(field, { "$slice" => val }) }
          end
        )
      end
    end

    # Tell the query to operate in snapshot mode.
    #
    # @example Add the snapshot option.
    #   optional.snapshot
    #
    # @return [ Optional ] The cloned optional.
    #
    # @since 1.0.0
    def snapshot
      clone.tap do |query|
        query.options.store(:snapshot, true)
      end
    end

    # Limits the results to only contain the fields not provided.
    #
    # @example Limit the results to the fields not provided.
    #   optional.without(:name, :dob)
    #
    # @param [ Array<Symbol> ] args The fields to ignore.
    #
    # @return [ Optional ] The cloned optional.
    #
    # @since 1.0.0
    def without(*args)
      option(*args) do |options|
        options.store(
          :fields, args.inject({}){ |sub, field| sub.tap { sub[field] = 0 }}
        )
      end
    end

    private

    # Add a single sort option.
    #
    # @api private
    #
    # @example Add a single sort option.
    #   optional.add_sort_option({}, :name, 1)
    #
    # @param [ Hash ] options The options.
    # @param [ String ] field The field name.
    # @param [ Integer ] direction The sort direction.
    #
    # @return [ Optional ] The cloned optional.
    #
    # @since 1.0.0
    def add_sort_option(options, field, direction)
      sorting = (options[:sort] || {}).dup
      sorting[field] = direction
      options.store(:sort, sorting)
    end

    # Take the provided criterion and store it as an option in the query
    # options.
    #
    # @api private
    #
    # @example Store the option.
    #   optional.option({ skip: 10 })
    #
    # @param [ Array ] args The options.
    #
    # @return [ Queryable ] The cloned queryable.
    #
    # @since 1.0.0
    def option(*args)
      clone.tap do |query|
        unless args.compact.empty?
          yield(query.options)
        end
      end
    end

    # Add multiple sort options at once.
    #
    # @api private
    #
    # @example Add multiple sort options.
    #   optional.sort_with_list(:name, :dob, 1)
    #
    # @param [ Array<String> ] fields The field names.
    # @param [ Integer ] direction The sort direction.
    #
    # @return [ Optional ] The cloned optional.
    #
    # @since 1.0.0
    def sort_with_list(*fields, direction)
      option(fields) do |options|
        fields.flatten.compact.each do |field|
          add_sort_option(options, field, direction)
        end
      end
    end
  end
end
