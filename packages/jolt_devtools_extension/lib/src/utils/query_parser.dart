import 'package:jolt_devtools_extension/src/models/jolt_node.dart';

/// Represents a single query predicate
class QueryPredicate {
  final bool isNegated;
  final bool Function(JoltNode node, DateTime now) matches;

  const QueryPredicate({
    required this.isNegated,
    required this.matches,
  });
}

/// Represents a query expression tree node
abstract class QueryExpression {
  bool evaluate(JoltNode node, DateTime now);
}

/// Leaf node representing a single predicate
class QueryPredicateExpression extends QueryExpression {
  final QueryPredicate predicate;

  QueryPredicateExpression(this.predicate);

  @override
  bool evaluate(JoltNode node, DateTime now) {
    final matched = predicate.matches(node, now);
    return predicate.isNegated ? !matched : matched;
  }
}

/// AND node: all children must be true
class QueryAndExpression extends QueryExpression {
  final List<QueryExpression> children;

  QueryAndExpression(this.children);

  @override
  bool evaluate(JoltNode node, DateTime now) {
    for (final child in children) {
      if (!child.evaluate(node, now)) {
        return false;
      }
    }
    return true;
  }
}

/// OR node: at least one child must be true
class QueryOrExpression extends QueryExpression {
  final List<QueryExpression> children;

  QueryOrExpression(this.children);

  @override
  bool evaluate(JoltNode node, DateTime now) {
    for (final child in children) {
      if (child.evaluate(node, now)) {
        return true;
      }
    }
    return false;
  }
}

/// Interface for matching query predicates against nodes
abstract class QueryMatcher {
  bool matchesFreeText(JoltNode node, String term);
  bool matchesKeyPredicate(
      JoltNode node, DateTime now, String key, String value);
  bool matchesNumeric(int actual, String value);
  bool matchesDep(JoltNode node, String condition);
  bool matchesSub(JoltNode node, String condition);
}

/// Parser for query expressions with support for OR and parentheses
class QueryParser {
  final List<String> tokens;
  final QueryMatcher matcher;
  int _index = 0;

  QueryParser(this.tokens, this.matcher);

  QueryExpression? parse() {
    if (tokens.isEmpty) {
      return null;
    }
    final expr = _parseOr();
    return expr;
  }

  QueryExpression _parseOr() {
    var left = _parseAnd();
    while (_hasToken() && (_peekToken() == '|' || _isOrKeyword())) {
      if (_isOrKeyword()) {
        _consumeOrKeyword();
      } else {
        _consumeToken(); // Consume '|'
      }
      final right = _parseAnd();
      if (left is QueryOrExpression) {
        left.children.add(right);
      } else {
        left = QueryOrExpression([left, right]);
      }
    }
    return left;
  }

  QueryExpression _parseAnd() {
    var expressions = <QueryExpression>[];
    var expr = _parseAtom();
    if (expr != null) {
      expressions.add(expr);
    }

    while (_hasToken() &&
        _peekToken() != ')' &&
        _peekToken() != '|' &&
        !_isOrKeyword()) {
      expr = _parseAtom();
      if (expr != null) {
        expressions.add(expr);
      } else {
        break;
      }
    }

    if (expressions.isEmpty) {
      // Return a dummy expression that always matches
      return QueryPredicateExpression(
        QueryPredicate(isNegated: false, matches: (_, __) => true),
      );
    }
    if (expressions.length == 1) {
      return expressions.first;
    }
    return QueryAndExpression(expressions);
  }

  QueryExpression? _parseAtom() {
    if (!_hasToken()) {
      return null;
    }

    if (_peekToken() == '(') {
      _consumeToken(); // Consume '('
      final expr = _parseOr();
      if (_hasToken() && _peekToken() == ')') {
        _consumeToken(); // Consume ')'
      }
      return expr;
    }

    final token = _consumeToken();
    if (token.isEmpty) {
      return null;
    }

    final isNegated = token.startsWith('-');
    final content = isNegated ? token.substring(1) : token;

    if (content.isEmpty) {
      return null;
    }

    // Check if it's a field query (contains ':') or numeric comparison
    final hasColon = content.contains(':');
    final hasNumericOp = RegExp(r'^[a-zA-Z_]+[<>=]+').hasMatch(content);

    if (hasColon) {
      final separatorIndex = content.indexOf(':');
      final key = content.substring(0, separatorIndex).toLowerCase();
      final value = content.substring(separatorIndex + 1);
      if (value.isEmpty) {
        return null;
      }

      // Handle dep:{id:2} and sub:{id:2} syntax
      if (key == 'dep' || key == 'sub') {
        if (value.startsWith('{') && value.endsWith('}')) {
          final innerCondition = value.substring(1, value.length - 1);
          return QueryPredicateExpression(
            QueryPredicate(
              isNegated: isNegated,
              matches: (node, now) {
                if (key == 'dep') {
                  return matcher.matchesDep(node, innerCondition);
                } else {
                  return matcher.matchesSub(node, innerCondition);
                }
              },
            ),
          );
        }
      }

      return QueryPredicateExpression(
        QueryPredicate(
          isNegated: isNegated,
          matches: (node, now) =>
              matcher.matchesKeyPredicate(node, now, key, value),
        ),
      );
    } else if (hasNumericOp) {
      // Parse numeric comparison: field>=value, field>value, field=value, etc.
      final match = RegExp(r'^([a-zA-Z_]+)([<>=]+)(.+)$').firstMatch(content);
      if (match != null) {
        final field = match.group(1)!.toLowerCase();
        final op = match.group(2)!;
        final valueStr = match.group(3)!;
        return QueryPredicateExpression(
          QueryPredicate(
            isNegated: isNegated,
            matches: (node, now) {
              int actual;
              switch (field) {
                case 'id':
                  actual = node.id;
                  break;
                case 'deps':
                  actual = node.dependencies.length;
                  break;
                case 'subs':
                  actual = node.subscribers.length;
                  break;
                default:
                  return false;
              }
              // Handle = operator separately for exact match
              if (op == '=') {
                final target = int.tryParse(valueStr);
                return target != null && actual == target;
              }
              // For other operators, use matchesNumeric
              return matcher.matchesNumeric(actual, '$op$valueStr');
            },
          ),
        );
      }
    }

    // Free text search
    return QueryPredicateExpression(
      QueryPredicate(
        isNegated: isNegated,
        matches: (node, _) => matcher.matchesFreeText(node, content),
      ),
    );
  }

  bool _hasToken() => _index < tokens.length;

  String _peekToken() => _hasToken() ? tokens[_index] : '';

  String _consumeToken() {
    if (!_hasToken()) {
      return '';
    }
    return tokens[_index++];
  }

  bool _isOrKeyword() {
    if (!_hasToken()) {
      return false;
    }
    final token = tokens[_index].toLowerCase();
    return token == 'or';
  }

  void _consumeOrKeyword() {
    if (_isOrKeyword()) {
      _index++;
    }
  }
}

/// Tokenizes a query string into tokens
List<String> tokenizeQuery(String input) {
  final tokens = <String>[];
  var i = 0;
  while (i < input.length) {
    // Skip whitespace
    if (input[i].trim().isEmpty) {
      i++;
      continue;
    }

    // Handle parentheses
    if (input[i] == '(' || input[i] == ')') {
      tokens.add(input[i]);
      i++;
      continue;
    }

    // Handle OR keyword (case insensitive)
    if (i + 1 < input.length &&
        input.substring(i, i + 2).toLowerCase() == 'or') {
      // Check if it's a complete word
      if ((i == 0 || input[i - 1].trim().isEmpty) &&
          (i + 2 >= input.length || input[i + 2].trim().isEmpty)) {
        tokens.add('|');
        i += 2;
        continue;
      }
    }

    // Handle pipe operator
    if (input[i] == '|') {
      tokens.add('|');
      i++;
      continue;
    }

    // Collect a token (word or quoted string)
    var start = i;
    if (input[i] == '"' || input[i] == "'") {
      // Quoted string
      final quote = input[i];
      i++;
      while (i < input.length && input[i] != quote) {
        if (input[i] == '\\' && i + 1 < input.length) {
          i += 2; // Skip escaped character
        } else {
          i++;
        }
      }
      if (i < input.length) {
        i++; // Skip closing quote
      }
      tokens.add(input.substring(start, i));
    } else {
      // Regular token
      while (i < input.length &&
          input[i].trim().isNotEmpty &&
          input[i] != '(' &&
          input[i] != ')' &&
          input[i] != '|') {
        // Check for OR keyword
        if (i + 1 < input.length &&
            input.substring(i, i + 2).toLowerCase() == 'or') {
          if (i + 2 >= input.length || input[i + 2].trim().isEmpty) {
            break; // Stop before OR keyword
          }
        }
        i++;
      }
      tokens.add(input.substring(start, i));
    }
  }
  return tokens;
}

/// Builds a query expression from a raw query string
QueryExpression? buildQueryExpression(String raw, QueryMatcher matcher) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) {
    return null;
  }

  final tokens = tokenizeQuery(raw);
  if (tokens.isEmpty) {
    return null;
  }

  final parser = QueryParser(tokens, matcher);
  return parser.parse();
}
